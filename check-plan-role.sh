#!/usr/bin/env bash
set -euo pipefail

# ---------------- variables (edit if needed) ----------------
ACCOUNT_ID="374320036370"
REGION="ap-south-1"
REPO="paras-31/High-Level-Infra-EKS"
BOOTSTRAP_BUCKET="tf-bootstrap-state-${ACCOUNT_ID}-${REGION}-an"
STATE_BUCKET="tf-state-${ACCOUNT_ID}-${REGION}"
LOCK_TABLE="terraform-state-lock"
KMS_ALIAS="alias/${STATE_BUCKET}"

PLAN_ROLE="gh-actions-terraform-plan"
APPLY_ROLE="gh-actions-terraform-apply"

WORKDIR="$(mktemp -d)"
echo "Working in $WORKDIR"
cd "$WORKDIR"

# ---------------- 1. GitHub OIDC provider ----------------
OIDC_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_ARN" >/dev/null 2>&1; then
  echo "OIDC provider already exists — skipping"
else
  echo "Creating GitHub OIDC provider…"
  aws iam create-open-id-connect-provider \
    --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 1c58a3a8518e8759bf075b76b750d4f2df264fcd
fi

# ---------------- 2. trust policy (shared) ----------------
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowGitHubActionsFromRepo",
      "Effect": "Allow",
      "Principal": {
        "Federated": "${OIDC_ARN}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${REPO}:*"
        }
      }
    }
  ]
}
EOF

# ---------------- 3. PLAN role inline policy ----------------
cat > plan-state-access.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "StateBucketRead",
      "Effect": "Allow",
      "Action": ["s3:ListBucket","s3:GetObject","s3:GetObjectVersion","s3:GetBucketVersioning"],
      "Resource": [
        "arn:aws:s3:::${BOOTSTRAP_BUCKET}",
        "arn:aws:s3:::${BOOTSTRAP_BUCKET}/*",
        "arn:aws:s3:::${STATE_BUCKET}",
        "arn:aws:s3:::${STATE_BUCKET}/*"
      ]
    },
    {
      "Sid": "StateLockReadWrite",
      "Effect": "Allow",
      "Action": ["dynamodb:DescribeTable","dynamodb:GetItem","dynamodb:PutItem","dynamodb:DeleteItem"],
      "Resource": "arn:aws:dynamodb:${REGION}:${ACCOUNT_ID}:table/${LOCK_TABLE}"
    },
    {
      "Sid": "StateKmsDecryptViaS3",
      "Effect": "Allow",
      "Action": ["kms:Decrypt","kms:DescribeKey"],
      "Resource": "arn:aws:kms:${REGION}:${ACCOUNT_ID}:key/*",
      "Condition": {
        "StringEquals": { "kms:ViaService": "s3.${REGION}.amazonaws.com" }
      }
    }
  ]
}
EOF

# ---------------- 4. APPLY role inline policies ----------------
cat > apply-iam.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "IamRoleManagement",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole","iam:DeleteRole","iam:GetRole","iam:UpdateRole","iam:UpdateAssumeRolePolicy",
        "iam:PassRole","iam:AttachRolePolicy","iam:DetachRolePolicy","iam:PutRolePolicy","iam:DeleteRolePolicy",
        "iam:GetRolePolicy","iam:ListAttachedRolePolicies","iam:ListRolePolicies","iam:ListRoleTags",
        "iam:ListRoles","iam:TagRole","iam:UntagRole"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IamPolicyManagement",
      "Effect": "Allow",
      "Action": [
        "iam:CreatePolicy","iam:DeletePolicy","iam:GetPolicy","iam:GetPolicyVersion","iam:ListPolicyVersions",
        "iam:ListPolicies","iam:CreatePolicyVersion","iam:DeletePolicyVersion","iam:SetDefaultPolicyVersion",
        "iam:TagPolicy","iam:UntagPolicy"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IamInstanceProfiles",
      "Effect": "Allow",
      "Action": [
        "iam:CreateInstanceProfile","iam:DeleteInstanceProfile","iam:GetInstanceProfile",
        "iam:AddRoleToInstanceProfile","iam:RemoveRoleFromInstanceProfile","iam:ListInstanceProfiles",
        "iam:ListInstanceProfilesForRole","iam:TagInstanceProfile","iam:UntagInstanceProfile"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IamOidc",
      "Effect": "Allow",
      "Action": [
        "iam:CreateOpenIDConnectProvider","iam:DeleteOpenIDConnectProvider","iam:GetOpenIDConnectProvider",
        "iam:ListOpenIDConnectProviders","iam:UpdateOpenIDConnectProviderThumbprint",
        "iam:AddClientIDToOpenIDConnectProvider","iam:RemoveClientIDFromOpenIDConnectProvider",
        "iam:TagOpenIDConnectProvider","iam:UntagOpenIDConnectProvider"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IamServiceLinkedRoles",
      "Effect": "Allow",
      "Action": [
        "iam:CreateServiceLinkedRole","iam:GetServiceLinkedRoleDeletionStatus","iam:DeleteServiceLinkedRole"
      ],
      "Resource": "*"
    }
  ]
}
EOF

cat > apply-state-access.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "StateBucketReadWrite",
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket","s3:GetBucketVersioning",
        "s3:GetObject","s3:GetObjectVersion",
        "s3:PutObject","s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::${BOOTSTRAP_BUCKET}",
        "arn:aws:s3:::${BOOTSTRAP_BUCKET}/*",
        "arn:aws:s3:::${STATE_BUCKET}",
        "arn:aws:s3:::${STATE_BUCKET}/*"
      ]
    },
    {
      "Sid": "StateLockReadWrite",
      "Effect": "Allow",
      "Action": ["dynamodb:DescribeTable","dynamodb:GetItem","dynamodb:PutItem","dynamodb:DeleteItem"],
      "Resource": "arn:aws:dynamodb:${REGION}:${ACCOUNT_ID}:table/${LOCK_TABLE}"
    },
    {
      "Sid": "StateKmsUseViaS3",
      "Effect": "Allow",
      "Action": ["kms:Encrypt","kms:Decrypt","kms:ReEncrypt*","kms:GenerateDataKey*","kms:DescribeKey"],
      "Resource": "arn:aws:kms:${REGION}:${ACCOUNT_ID}:key/*",
      "Condition": {
        "StringEquals": { "kms:ViaService": "s3.${REGION}.amazonaws.com" }
      }
    }
  ]
}
EOF

# ---------------- 5. create/update PLAN role ----------------
if aws iam get-role --role-name "$PLAN_ROLE" >/dev/null 2>&1; then
  echo "$PLAN_ROLE already exists — updating trust policy"
  aws iam update-assume-role-policy --role-name "$PLAN_ROLE" \
    --policy-document file://trust-policy.json
else
  echo "Creating $PLAN_ROLE"
  aws iam create-role --role-name "$PLAN_ROLE" \
    --assume-role-policy-document file://trust-policy.json \
    --description "Read-only role for GitHub Actions terraform plan"
fi

aws iam attach-role-policy --role-name "$PLAN_ROLE" \
  --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess

aws iam put-role-policy --role-name "$PLAN_ROLE" \
  --policy-name state-backend-access \
  --policy-document file://plan-state-access.json

# ---------------- 6. create/update APPLY role ----------------
if aws iam get-role --role-name "$APPLY_ROLE" >/dev/null 2>&1; then
  echo "$APPLY_ROLE already exists — updating trust policy"
  aws iam update-assume-role-policy --role-name "$APPLY_ROLE" \
    --policy-document file://trust-policy.json
else
  echo "Creating $APPLY_ROLE"
  aws iam create-role --role-name "$APPLY_ROLE" \
    --assume-role-policy-document file://trust-policy.json \
    --description "Write role for GitHub Actions terraform apply / destroy"
fi

aws iam attach-role-policy --role-name "$APPLY_ROLE" \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess

aws iam put-role-policy --role-name "$APPLY_ROLE" \
  --policy-name iam-management \
  --policy-document file://apply-iam.json

aws iam put-role-policy --role-name "$APPLY_ROLE" \
  --policy-name state-backend-access \
  --policy-document file://apply-state-access.json

# ---------------- 7. show the ARNs ----------------
echo
echo "================================================================"
echo "DONE. Add these to GitHub → Settings → Secrets → Actions:"
echo "----------------------------------------------------------------"
echo "AWS_PLAN_ROLE_ARN  = $(aws iam get-role --role-name $PLAN_ROLE  --query 'Role.Arn' --output text)"
echo "AWS_APPLY_ROLE_ARN = $(aws iam get-role --role-name $APPLY_ROLE --query 'Role.Arn' --output text)"
echo "================================================================"