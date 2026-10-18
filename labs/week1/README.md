# Week 1: Automating Secure Onboarding at Scale

**Module:** Security & Identity Management on AWS · **Client:** Onward Logistics · **Region:** eu-west-1

Onward onboards 5 to 10 engineers a month, and each one's AWS access is currently set up by hand in the console. This lab replaces that with one CloudFormation template in Git, deployed by Git sync. Every engineer gets the same least-privilege access each time, every change is traceable to a person and a time, and the on-call engineer can never create or terminate compute.

- Discovery report: [Discovery Report - Automating Secure Onboarding at Scale.docx](<Discovery Report - Automating Secure Onboarding at Scale.docx>)
- Template: [template.yaml](template.yaml) · Deployment file: [deployment.yaml](deployment.yaml) · Git sync wiring: [git-sync.yaml](git-sync.yaml)

## How access is controlled

```mermaid
flowchart LR
    subgraph Git["GitHub: main branch"]
        T[template.yaml + deployment.yaml]
    end
    T -- Git sync --> CFN[CloudFormation stack<br/>onward-dev-iam-onboarding]

    CFN --> SM[Secrets Manager<br/>3 generated first passwords]
    CFN --> TR[CloudTrail trail + S3 log bucket]
    CFN --> BU[Budget alert]

    subgraph IAM
        AE[onward-dev-all-engineers<br/>IAMUserChangePassword]
        SG[onward-dev-storage-engineers<br/>AmazonS3FullAccess]
        CG[onward-dev-compute-engineers<br/>AmazonEC2FullAccess]
        OG[onward-dev-oncall-observers<br/>AmazonEC2ReadOnlyAccess]

        U1[s3-user]
        U2[ec2-user-1]
        U3[ec2-user-2]

        B3{{observer boundary<br/>Describe only + explicit Deny<br/>RunInstances / TerminateInstances}}
    end

    CFN --> IAM
    SM -. first password .-> U1 & U2 & U3
    AE --- U1 & U2 & U3
    SG --- U1
    CG --- U2
    OG --- U3
    B3 -. caps .-> U3
    TR --- BP[/bucket policy: no IAM user can<br/>delete or alter the logs/]
```

**Groups give each role its day-one access** through AWS managed policies. **The on-call engineer also has a permissions boundary**, so their effective permissions are their group policies AND the boundary. However many policies are attached to `ec2-user-2` or their group later, the boundary is the ceiling.

## Design decisions

| Decision | Reason (in client terms) |
| --- | --- |
| AWS managed policies on **groups**, not policies written per user | The brief asks not to recreate entity-specific policies. Access belongs to the role, so the tenth hire is set up exactly like the first. |
| A **permissions boundary on `ec2-user-2`** | The client's one hard guarantee is that the on-call engineer can never create or terminate compute, "not even if someone later loosens their group's permissions". A boundary is the AWS mechanism that caps a user regardless of what is attached later. Boundaries attach to users or roles, not groups. |
| The on-call boundary allows `Describe*` only, plus an **explicit Deny** on launch and terminate actions | An explicit Deny always wins and documents the intent. `ec2:Get*` is left out on purpose, because it includes `GetPasswordData`, which retrieves Windows administrator passwords. |
| The audit **bucket policy denies every IAM user** from deleting, overwriting or loosening the logs | `AmazonS3FullAccess` would otherwise let the storage engineer delete the evidence of who changed access. A resource policy protects the logs from every user, administrators included, not just one engineer. CloudTrail still writes, and stack changes still flow through the deployment role. |
| **No inline policies** anywhere | A mandatory requirement. Every permission is a reusable managed policy that auditors can see in one place. |
| **Secrets Manager** generates first passwords, read with a `{{resolve:secretsmanager:…}}` dynamic reference, with `PasswordResetRequired: true` | No plain-text credential exists in Git, chat or the template, and each engineer must replace it with their own password at first sign-in. |
| Secrets and the log bucket have **no fixed names** | Deleted secrets are held for a recovery window and the log bucket is retained, so fixed names would block a rebuild from the repository. |
| A lab-owned **CloudTrail trail** with log file validation, even though Control Tower already runs an organisation trail | The Head of Security can read the evidence in this account. Validation proves the log files weren't altered. |
| The log bucket is **retained** when the stack is deleted, and expires logs after 365 days | Audit logs should outlive the infrastructure they describe, and the expiry keeps storage cost bounded. |
| **Stack tags** in `deployment.yaml` | One place applies `Project`, `Owner` and `Environment` to every taggable resource. |
| The budget email is kept in **SSM Parameter Store** | This repository is public, so the address stays out of Git. |
| Git sync's connection, repository link, role and sync configuration are **also CloudFormation** | Nothing is clicked together. The only console action is the GitHub connection approval, which AWS requires a person to do. |

## Deploy

All commands use the lab profile: `export AWS_PROFILE=onward-logistics`.

**1. Shared GitHub connection (once for all labs, two passes).**

```bash
aws cloudformation deploy \
  --stack-name onward-github-connection \
  --template-file bootstrap/github-connection.yaml \
  --parameter-overrides GitHubOwner=Ghaby-X RepositoryName=aws-developer-associate-labs \
  --tags Project=onward Owner="Gabriel Anyaele" Environment=dev
```

Approve the pending `onward-github` connection in the console: **Developer Tools → Settings → Connections → Update pending connection**. Then link the repository:

```bash
aws cloudformation deploy \
  --stack-name onward-github-connection \
  --template-file bootstrap/github-connection.yaml \
  --parameter-overrides GitHubOwner=Ghaby-X RepositoryName=aws-developer-associate-labs CreateRepositoryLink=true \
  --tags Project=onward Owner="Gabriel Anyaele" Environment=dev
```

**2. Week 1 Git sync wiring.**

```bash
aws cloudformation deploy \
  --stack-name onward-dev-week1-git-sync \
  --template-file labs/week1/git-sync.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides BudgetAlertEmail=<your-email> \
  --tags Project=onward Owner="Gabriel Anyaele" Environment=dev
```

Git sync then creates the `onward-dev-iam-onboarding` stack from `labs/week1/deployment.yaml`. From this point, every access change is a commit to `main`.

**3. Hand over first passwords.** An administrator reads each secret (its ARN is in the stack outputs) and passes the password to the engineer over a private channel:

```bash
aws secretsmanager get-secret-value --secret-id <secret-arn> --query SecretString --output text
```

## Evidence plan

| Client check | How it is proven | Evidence |
| --- | --- | --- |
| Each engineer can do their job on day one | Sign in as each user and do the role's task: list and upload to S3, describe instances, launch a test instance | `evidence/` |
| …and cannot do more | Each user tries an action outside their role and gets `AccessDenied` | `evidence/` |
| On-call engineer still can't create or terminate compute after permissions are added | Commit `AttachExtraOncallPermissions: "true"`, then `ec2-user-2` tries `RunInstances` and `TerminateInstances` (and the IAM policy simulator is run on that user). Then revert. | `evidence/` |
| Head of Security can see how access was defined and who changed it | Git history of `labs/week1/`, Git sync deployment history, and CloudTrail events for the IAM changes | `evidence/` |
| The whole setup can be rebuilt from the repository | Delete the onboarding stack, re-run the sync, and it comes back identical | `evidence/` |

## Cleanup

```bash
aws cloudformation delete-stack --stack-name onward-dev-week1-git-sync
aws cloudformation delete-stack --stack-name onward-dev-iam-onboarding
# The audit log bucket is retained by design, and its bucket policy blocks every IAM user
# (including admins) from deleting it. Remove it after grading using an assumed role
# (e.g. your IAM Identity Center admin role) or the account root user.
# Delete onward-github-connection only after the last lab is finished.
```
