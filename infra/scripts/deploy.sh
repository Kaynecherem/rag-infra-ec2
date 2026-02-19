#!/bin/bash
set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────
# Set these or pass as environment variables
EC2_HOST="${EC2_HOST:-}"
SSH_KEY="${SSH_KEY:-~/.ssh/insurance-rag.pem}"
APP_DIR="/opt/insurance-rag"

if [ -z "$EC2_HOST" ]; then
  echo "Usage: EC2_HOST=<ip> bash infra/scripts/deploy.sh"
  echo "   or: EC2_HOST=<ip> SSH_KEY=~/.ssh/mykey.pem bash infra/scripts/deploy.sh"
  exit 1
fi

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Insurance RAG - Deploy to EC2${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"

# ── Sync code to EC2 ────────────────────────────────────────────────
echo -e "\n${YELLOW}→ Syncing code to EC2...${NC}"
rsync -avz --delete \
  --exclude '.git' \
  --exclude 'node_modules' \
  --exclude '__pycache__' \
  --exclude '.env' \
  --exclude 'venv' \
  --exclude '.venv' \
  --exclude 'frontend/node_modules' \
  --exclude 'frontend/.next' \
  --exclude 'infra/terraform/.terraform' \
  --exclude 'infra/terraform/terraform.tfvars' \
  --exclude 'infra/terraform/terraform.tfstate*' \
  -e "ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no" \
  . ec2-user@${EC2_HOST}:${APP_DIR}/

echo -e "${GREEN}✓ Code synced${NC}"

# ── Rebuild and restart on EC2 ───────────────────────────────────────
echo -e "\n${YELLOW}→ Rebuilding containers...${NC}"
ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no ec2-user@${EC2_HOST} << 'REMOTE'
cd /opt/insurance-rag
sudo docker compose down
sudo docker compose up -d --build
echo "Waiting for health check..."
sleep 10
curl -sf http://localhost/health && echo " ✓ API healthy" || echo " ✗ API not responding"
sudo docker compose ps
REMOTE

echo -e "${GREEN}✓ Deployment complete!${NC}"
echo -e "\n${GREEN}═══════════════════════════════════════════════════${NC}"
