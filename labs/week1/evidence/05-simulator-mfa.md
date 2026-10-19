## IAM policy simulator: MFA required (onward-dev-require-mfa, commit 28885c7)

Generated 2026-10-19T01:42:50Z with `aws iam simulate-principal-policy` against account 448049788660. The simulator evaluates each user's group policies and permissions boundary together. Unless marked otherwise, rows assume the user signed in **with MFA**.

| User | Action | Decision | Boundary decision |
| --- | --- | --- | --- |
| s3-user | `s3:ListAllMyBuckets` | allowed | n/a (no boundary) |
| s3-user | `s3:PutObject` | allowed | n/a (no boundary) |
| s3-user | `s3:GetObject` | allowed | n/a (no boundary) |
| s3-user | `ec2:DescribeInstances` | **implicitDeny** | n/a (no boundary) |
| s3-user | `ec2:RunInstances` | **implicitDeny** | n/a (no boundary) |
| s3-user | `iam:CreateUser` | **implicitDeny** | n/a (no boundary) |
| ec2-user-1 | `ec2:DescribeInstances` | allowed | n/a (no boundary) |
| ec2-user-1 | `ec2:RunInstances` | allowed | n/a (no boundary) |
| ec2-user-1 | `ec2:TerminateInstances` | allowed | n/a (no boundary) |
| ec2-user-1 | `s3:ListAllMyBuckets` | **implicitDeny** | n/a (no boundary) |
| ec2-user-1 | `s3:PutObject` | **implicitDeny** | n/a (no boundary) |
| ec2-user-1 | `iam:CreateUser` | **implicitDeny** | n/a (no boundary) |
| ec2-user-2 | `ec2:DescribeInstances` | allowed | allowed |
| ec2-user-2 | `ec2:DescribeInstanceStatus` | allowed | allowed |
| ec2-user-2 | `cloudwatch:GetMetricStatistics` | allowed | allowed |
| ec2-user-2 | `ec2:RunInstances` | **explicitDeny** | **denied** |
| ec2-user-2 | `ec2:TerminateInstances` | **explicitDeny** | **denied** |
| ec2-user-2 | `ec2:StartInstances` | **explicitDeny** | **denied** |
| ec2-user-2 | `ec2:StopInstances` | **implicitDeny** | **denied** |
| ec2-user-2 | `ec2:GetPasswordData` | **implicitDeny** | **denied** |
| ec2-user-2 | `s3:ListAllMyBuckets` | **implicitDeny** | **denied** |
| ec2-user-2 | `iam:CreateUser` | **implicitDeny** | **denied** |
| ec2-user-2 | `iam:DeleteUserPermissionsBoundary` | **implicitDeny** | **denied** |
| s3-user | `iam:ChangePassword` (own user) | allowed | n/a (no boundary) |
| ec2-user-1 | `iam:ChangePassword` (own user) | allowed | n/a (no boundary) |
| ec2-user-2 | `iam:ChangePassword` (own user) | allowed | allowed |

### Without MFA

| User | Action | Decision |
| --- | --- | --- |
| s3-user | `s3:ListAllMyBuckets` | **explicitDeny** |
| ec2-user-1 | `ec2:RunInstances` | **explicitDeny** |
| ec2-user-2 | `ec2:DescribeInstances` | **explicitDeny** |

### MFA self-enrolment before MFA (must be allowed, or nobody could ever sign in)

| User | Action | Decision | Boundary decision |
| --- | --- | --- | --- |
| s3-user | `iam:CreateVirtualMFADevice` | allowed | n/a (no boundary) |
| s3-user | `iam:EnableMFADevice` | allowed | n/a (no boundary) |
| s3-user | `iam:ListMFADevices` | allowed | n/a (no boundary) |
| ec2-user-2 | `iam:CreateVirtualMFADevice` | allowed | allowed |
| ec2-user-2 | `iam:EnableMFADevice` | allowed | allowed |
| ec2-user-2 | `iam:ListMFADevices` | allowed | allowed |
