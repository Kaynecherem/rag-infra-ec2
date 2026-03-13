# Insurance RAG - Production Deployment Guide (EC2 + CloudFront)

## Architecture

```
                     ┌──────────────────────────┐
   Users ───────────►│  CloudFront (HTTPS)       │
   Widget ──────────►│  *.cloudfront.net         │
                     └────────────┬─────────────┘
                                  │ HTTP
                     ┌────────────▼─────────────┐
                     │     EC2 (t2.micro)        │
                     │  ┌─────────────────────┐  │
                     │  │  Docker Compose      │  │
                     │  │  ┌───────────────┐  │  │
                     │  │  │   FastAPI API  │  │  │
                     │  │  │   (port 80)    │  │  │
                     │  │  └───────────────┘  │  │
                     │  │  ┌───────────────┐  │  │
                     │  │  │  PostgreSQL 15 │  │  │
                     │  │  └───────────────┘  │  │
                     │  │  ┌───────────────┐  │  │
                     │  │  │   Redis 7      │  │  │
                     │  │  └───────────────┘  │  │
                     │  └─────────────────────┘  │
                     └───────────────────────────┘
   
   External: Pinecone (vectors) · OpenAI (embeddings) · Claude (LLM) · S3 (files)
   Frontend: Vercel (free tier)
```

## Estimated Monthly Cost

| Service | Tier | Cost |
|---------|------|------|
| EC2 t2.micro | Free tier (12 months) | **$0** |
| EBS 20GB gp3 | Free tier (30GB) | **$0** |
| Elastic IP | Free (when attached) | **$0** |
| CloudFront | 1TB free/month | **$0** |
| S3 | 5GB free | **$0** |
| Pinecone | Free tier | **$0** |
| OpenAI embeddings | ~1M tokens/mo | ~$1 |
| Anthropic Claude | ~100 queries/day | ~$5-15 |
| Vercel (frontend) | Free tier | **$0** |
| **Total** | | **~$6-16/mo** |

> After the 12-month free tier expires, EC2 t2.micro is ~$8.50/mo.
> When you need to scale: transition to ECS Fargate + RDS.

---

## Prerequisites

- AWS account (create at https://aws.amazon.com)
- AWS CLI installed
- Terraform installed
- Your API keys: OpenAI, Anthropic, Pinecone

### Install Tools (Windows)

```powershell
# AWS CLI
winget install Amazon.AWSCLI

# Terraform
winget install Hashicorp.Terraform

# Verify
aws --version
terraform version
```

---

## Step 1: AWS Account Setup

### 1a. Create Account
1. Go to https://aws.amazon.com → Create Account
2. Use business email if possible
3. Add credit card
4. Select **Basic Support** (free)
5. **Enable MFA** on root account (Security Credentials → MFA)

### 1b. Create IAM Admin User
1. Go to **IAM** → **Users** → **Create User**
2. Name: `irag-admin`
3. Check **Provide user access to the AWS Management Console**
4. **Attach policies directly** → `AdministratorAccess`
5. Create user, save credentials

### 1c. Create Access Keys
1. IAM → Users → `irag-admin` → **Security Credentials**
2. **Create access key** → CLI → Download CSV

### 1d. Configure CLI
```powershell
aws configure
# AWS Access Key ID: <from step 1c>
# AWS Secret Access Key: <from step 1c>
# Default region: us-east-1
# Default output: json

# Verify
aws sts get-caller-identity
```

---

## Step 2: Create SSH Key Pair

You need this to SSH into the EC2 instance.

```powershell
# Create key pair in AWS
aws ec2 create-key-pair --key-name insurance-rag --query 'KeyMaterial' --output text > ~/.ssh/insurance-rag.pem

# Set permissions (Git Bash or WSL)
chmod 400 ~/.ssh/insurance-rag.pem
```

Or via AWS Console: **EC2** → **Key Pairs** → **Create key pair** → Download `.pem` file.

---

## Step 3: Configure Terraform

Create `infra/terraform/terraform.tfvars`:

```hcl
ssh_key_name = "insurance-rag"

# Restrict SSH to your IP (find yours at https://whatismyip.com)
my_ip = "YOUR.IP.HERE/32"

# API keys
openai_api_key    = "sk-proj-..."
anthropic_api_key = "sk-ant-..."
pinecone_api_key  = "pcsk_..."
secret_key        = "GENERATE_A_RANDOM_32_CHAR_STRING"
```

Generate a random secret key:
```powershell
python -c "import secrets; print(secrets.token_urlsafe(32))"
```

**Add to `.gitignore`:**
```
infra/terraform/terraform.tfvars
infra/terraform/.terraform/
infra/terraform/terraform.tfstate*
```

---

## Step 4: Deploy Infrastructure

```powershell
cd infra/terraform

# Initialize
terraform init

# Preview
terraform plan

# Deploy (~5 minutes)
terraform apply
```

**Save the outputs!** Especially:
- `cloudfront_url` — your HTTPS API URL
- `ec2_public_ip` — for SSH access
- `ssh_command` — ready-to-use SSH command

---

## Step 5: Deploy Application Code

Wait ~2 minutes after `terraform apply` for the EC2 bootstrap to finish installing Docker.

### Option A: Using rsync (recommended)

From your project root on Windows (use Git Bash):

```bash
EC2_HOST=<ec2_public_ip> SSH_KEY=~/.ssh/insurance-rag.pem bash infra/scripts/deploy.sh
```

### Option B: Manual deploy via SSH

```powershell
# SSH into the server
ssh -i ~/.ssh/insurance-rag.pem ec2-user@<EC2_PUBLIC_IP>

# Check bootstrap completed
cat /var/log/insurance-rag-setup.log

# The .env and docker-compose.yml are already there from bootstrap
# Now get your application code there:

# Option: clone from git
cd /opt/insurance-rag
sudo git clone https://github.com/YOU/insurance-rag.git .

# Option: or use SCP from local machine (run from local, not SSH)
# scp -i ~/.ssh/insurance-rag.pem -r ./app ./requirements.txt ec2-user@<IP>:/opt/insurance-rag/

# Build and start
sudo docker compose up -d --build

# Watch logs
sudo docker compose logs -f api
```

---

## Step 6: Verify Deployment

```powershell
# Direct to EC2 (HTTP)
curl http://<EC2_PUBLIC_IP>/health

# Via CloudFront (HTTPS) - may take 5-10 min for first propagation
curl https://<CLOUDFRONT_DOMAIN>/health
```

Both should return: `{"status":"healthy","service":"insurance-rag"}`

---

## Step 7: Deploy Frontend to Vercel

1. Push `frontend/` to GitHub
2. Go to https://vercel.com → Import Project
3. Set root directory: `frontend`
4. Add environment variable:
   ```
   NEXT_PUBLIC_API_URL = https://<CLOUDFRONT_DOMAIN>
   ```
5. Deploy

Update `frontend/lib/api.ts` first line:
```typescript
const API_BASE = process.env.NEXT_PUBLIC_API_URL
  ? `${process.env.NEXT_PUBLIC_API_URL}/api/v1`
  : "/api/v1";
```

---

## Step 8: Configure Widget

Update the widget script tag with your CloudFront URL:

```html
<script
  src="https://<CLOUDFRONT_DOMAIN>/widget/insurance-rag-widget.js"
  data-tenant-id="<TENANT_UUID>"
  data-api-url="https://<CLOUDFRONT_DOMAIN>"
></script>
```

---

## Updating the Application

After code changes, from Git Bash:

```bash
EC2_HOST=<ip> bash infra/scripts/deploy.sh
```

This rsyncs your code and rebuilds containers. Takes ~1-2 minutes.

To invalidate CloudFront cache after deploy:
```powershell
aws cloudfront create-invalidation --distribution-id <DIST_ID> --paths "/*"
```

---

## Scaling Up Later

When you outgrow the single EC2:

| Trigger | Action |
|---------|--------|
| Need more CPU/RAM | Upgrade to t3.small ($15/mo) |
| Need HA / zero-downtime deploys | Move to ECS Fargate + ALB |
| DB needs dedicated resources | Move PostgreSQL to RDS |
| Heavy traffic | Add CloudFront caching rules |
| Multiple regions | ECS + global CloudFront |

The app is already containerized, so migration is straightforward.

---

## Troubleshooting

### Can't SSH in
```powershell
# Check security group allows your IP
aws ec2 describe-security-groups --filters "Name=tag:Name,Values=insurance-rag-ec2-sg" --query 'SecurityGroups[0].IpPermissions[0]'

# Your IP may have changed - update my_ip in terraform.tfvars and re-apply
terraform apply
```

### EC2 bootstrap didn't finish
```powershell
ssh -i ~/.ssh/insurance-rag.pem ec2-user@<IP>
cat /var/log/insurance-rag-setup.log
```

### Containers won't start
```bash
cd /opt/insurance-rag
sudo docker compose logs api
sudo docker compose logs db
```

### CloudFront returns 502
- EC2 might still be starting - wait 2 minutes
- Check: `curl http://<EC2_IP>/health` directly
- CloudFront points to HTTP on port 80 — make sure API binds to port 80

### Out of disk space
```bash
# Clean Docker
sudo docker system prune -af
# Check space
df -h
```
