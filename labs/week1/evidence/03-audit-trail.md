## Audit trail: who changed access, and when

Every change to who can access what is answered twice: **Git** records who decided the change and when, and **CloudTrail** records the AWS API call that applied it. Times in Git are UTC+2; CloudTrail times are UTC.

### 1. Git history of the access definition

`git log -- labs/week1/deployment.yaml` (the template follows the same pattern):

| Commit | Time (UTC+2) | Author | Change |
| --- | --- | --- | --- |
| `b9e85de` | 2026-10-19 01:05 | Gabriel Anyaele | `feat(week1)`: onboard s3-user, ec2-user-1 and ec2-user-2 |
| `dec18d4` | 2026-10-19 02:00 | Gabriel Anyaele | `test(week1)`: attach AmazonEC2FullAccess to the on-call group to verify the boundary |
| `241a6d7` | 2026-10-19 02:48 | Gabriel Anyaele | `revert(week1)`: detach AmazonEC2FullAccess after the boundary test |

### 2. CloudTrail events those commits caused

IAM is a global service, so its events are in the **us-east-1** event history, and the lab trail `onward-dev-audit-trail` delivers them to the audit bucket. Query used:

```bash
aws cloudtrail lookup-events --region us-east-1 \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AttachGroupPolicy
```

| Time (UTC) | Event | Target | Policy / boundary | Performed by | Result |
| --- | --- | --- | --- | --- | --- |
| 2026-10-18 23:28:33 | AttachGroupPolicy | onward-dev-all-engineers | IAMUserChangePassword | Git sync role | success |
| 2026-10-18 23:28:33 | AttachGroupPolicy | onward-dev-compute-engineers | AmazonEC2FullAccess | Git sync role | success |
| 2026-10-18 23:28:33 | AttachGroupPolicy | onward-dev-storage-engineers | AmazonS3FullAccess | Git sync role | success |
| 2026-10-18 23:28:36 | AttachGroupPolicy | onward-dev-oncall-observers | AmazonEC2ReadOnlyAccess | Git sync role | success |
| 2026-10-18 23:28:36 | CreateUser | s3-user | none | Git sync role | success |
| 2026-10-18 23:28:37 | CreateUser | ec2-user-1 | none | Git sync role | success |
| 2026-10-18 23:28:40 | CreateUser | ec2-user-2 | **onward-dev-oncall-observer-boundary** | Git sync role | success |
| 2026-10-18 23:29:12 | CreateLoginProfile | s3-user, ec2-user-1 | none | Git sync role | success |
| 2026-10-18 23:29:15 | CreateLoginProfile | ec2-user-2 | none | Git sync role | success |
| 2026-10-19 00:24:31 | DetachGroupPolicy | onward-dev-oncall-observers | AmazonEC2FullAccess | user/gabriel | NoSuchEntity (see note) |
| 2026-10-19 00:27:18 | AttachGroupPolicy | onward-dev-oncall-observers | AmazonEC2FullAccess | Git sync role | success (commit `dec18d4`) |
| 2026-10-19 00:49:01 | DetachGroupPolicy | onward-dev-oncall-observers | AmazonEC2FullAccess | Git sync role | success (commit `241a6d7`) |

"Git sync role" is `assumed-role/onward-dev-week1-git-sync/CfnSync`: every change came from a commit on `main`, not from a person in the console.

**Note on the 00:24 event.** The first attempt to deploy `dec18d4` failed because the Git sync role was missing a permission, and the stack rolled back. The administrator ran `continue-update-rollback` to recover it, and CloudFormation tried to detach a policy that had never been attached, which produced `NoSuchEntity`. Git sync noticed that change outside Git and paused itself with a sync blocker until the administrator resolved it with a written reason. That is the audit control working: changes made outside Git are visible and stop automation until someone signs them off.

### 3. Log integrity

The trail has log file validation enabled, and the bucket policy denies every IAM user, administrators included, from deleting or overwriting the logs (`s3-user-3-delete-audit-logs-denied.png`). To verify the log files haven't been altered:

```bash
aws cloudtrail validate-logs --trail-arn arn:aws:cloudtrail:eu-west-1:448049788660:trail/onward-dev-audit-trail \
  --start-time 2026-10-18T23:00:00Z
```
