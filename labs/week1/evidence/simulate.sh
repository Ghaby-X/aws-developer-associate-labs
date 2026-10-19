#!/usr/bin/env bash
# Usage: simulate.sh <label>  -> markdown table of allowed/denied actions per engineer
set -euo pipefail
ACCT=448049788660
declare -A ACTIONS=(
  [s3-user]="s3:ListAllMyBuckets s3:PutObject s3:GetObject ec2:DescribeInstances ec2:RunInstances iam:CreateUser"
  [ec2-user-1]="ec2:DescribeInstances ec2:RunInstances ec2:TerminateInstances s3:ListAllMyBuckets s3:PutObject iam:CreateUser"
  [ec2-user-2]="ec2:DescribeInstances ec2:DescribeInstanceStatus cloudwatch:GetMetricStatistics ec2:RunInstances ec2:TerminateInstances ec2:StartInstances ec2:StopInstances ec2:GetPasswordData s3:ListAllMyBuckets iam:CreateUser iam:DeleteUserPermissionsBoundary"
)
echo "## IAM policy simulator: $1"
echo
echo "Generated $(date -u +%FT%TZ) with \`aws iam simulate-principal-policy\` against account $ACCT. The simulator evaluates each user's group policies and permissions boundary together."
echo
echo "| User | Action | Decision | Boundary decision |"
echo "| --- | --- | --- | --- |"
for u in s3-user ec2-user-1 ec2-user-2; do
  args=(--policy-source-arn "arn:aws:iam::$ACCT:user/$u" --action-names ${ACTIONS[$u]})
  aws iam simulate-principal-policy "${args[@]}" --resource-arns '*' --output json \
  | python3 -I -c "
import json,sys
u=sys.argv[1]
for r in json.load(sys.stdin)['EvaluationResults']:
    b=(r.get('PermissionsBoundaryDecisionDetail') or {}).get('AllowedByPermissionsBoundary')
    b='n/a (no boundary)' if b is None else ('allowed' if b else '**denied**')
    d=r['EvalDecision']; d=d if d=='allowed' else f'**{d}**'
    print(f\"| {u} | \`{r['EvalActionName']}\` | {d} | {b} |\")
" "$u"
done
# Own-password change: IAMUserChangePassword is scoped to the caller's own user ARN.
for u in s3-user ec2-user-1 ec2-user-2; do
  aws iam simulate-principal-policy --policy-source-arn "arn:aws:iam::$ACCT:user/$u" \
    --action-names iam:ChangePassword --resource-arns "arn:aws:iam::$ACCT:user/$u" \
    --context-entries "ContextKeyName=aws:username,ContextKeyValues=$u,ContextKeyType=string" --output json \
  | python3 -I -c "
import json,sys
u=sys.argv[1]
for r in json.load(sys.stdin)['EvaluationResults']:
    b=(r.get('PermissionsBoundaryDecisionDetail') or {}).get('AllowedByPermissionsBoundary')
    b='n/a (no boundary)' if b is None else ('allowed' if b else '**denied**')
    d=r['EvalDecision']; d=d if d=='allowed' else f'**{d}**'
    print(f\"| {u} | \`iam:ChangePassword\` (own user) | {d} | {b} |\")
" "$u"
done
