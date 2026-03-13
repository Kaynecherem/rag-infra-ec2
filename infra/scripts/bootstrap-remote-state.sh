#!/bin/bash
set -euo pipefail

# ══════════════════════════════════════════════════════════════════════
# Bootstrap Terraform Remote State (S3 + DynamoDB)
# Run this ONCE before first terraform init
# ══════════════════════════════════════════════════════════════════════

BUCKET_NAME="insurance-rag-tfstate"
TABLE_NAME="insurance-rag-tflock"
REGION="us-east-1"
PROFILE="insurance-rag"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Bootstrapping Terraform Remote State${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"

# ── Check AWS credentials ────────────────────────────────────────────
echo -e "\n${YELLOW}→ Verifying AWS credentials...${NC}"
if ! aws sts get-caller-identity --profile "$PROFILE" &>/dev/null; then
  echo -e "${RED}✗ AWS profile '$PROFILE' not configured. Run: aws configure --profile $PROFILE${NC}"
  exit 1
fi
echo -e "${GREEN}✓ AWS credentials OK${NC}"

# ── Create S3 bucket ─────────────────────────────────────────────────
echo -e "\n${YELLOW}→ Creating S3 bucket: ${BUCKET_NAME}...${NC}"
if aws s3api head-bucket --bucket "$BUCKET_NAME" --profile "$PROFILE" 2>/dev/null; then
  echo -e "${GREEN}✓ Bucket already exists${NC}"
else
  aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --profile "$PROFILE"
  echo -e "${GREEN}✓ Bucket created${NC}"
fi

# Enable versioning (so you can recover old state)
aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled \
  --profile "$PROFILE"
echo -e "${GREEN}✓ Versioning enabled${NC}"

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket "$BUCKET_NAME" \
  --server-side-encryption-configuration '{
    "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
  }' \
  --profile "$PROFILE"
echo -e "${GREEN}✓ Encryption enabled${NC}"

# Block public access
aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration '{
    "BlockPublicAcls": true,
    "IgnorePublicAcls": true,
    "BlockPublicPolicy": true,
    "RestrictPublicBuckets": true
  }' \
  --profile "$PROFILE"
echo -e "${GREEN}✓ Public access blocked${NC}"

# ── Create DynamoDB table for state locking ──────────────────────────
echo -e "\n${YELLOW}→ Creating DynamoDB table: ${TABLE_NAME}...${NC}"
if aws dynamodb describe-table --table-name "$TABLE_NAME" --region "$REGION" --profile "$PROFILE" &>/dev/null; then
  echo -e "${GREEN}✓ Table already exists${NC}"
else
  aws dynamodb create-table \
    --table-name "$TABLE_NAME" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "$REGION" \
    --profile "$PROFILE"

  # Wait for table to be active
  echo "  Waiting for table to become active..."
  aws dynamodb wait table-exists --table-name "$TABLE_NAME" --region "$REGION" --profile "$PROFILE"
  echo -e "${GREEN}✓ Table created${NC}"
fi

echo -e "\n${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Remote state bootstrapped!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo ""
echo "  S3 Bucket:      ${BUCKET_NAME}"
echo "  DynamoDB Table:  ${TABLE_NAME}"
echo "  Region:          ${REGION}"
echo ""
echo "  Next: cd terraform && terraform init"
echo ""
