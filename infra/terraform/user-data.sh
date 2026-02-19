#!/bin/bash
set -euo pipefail
exec > /var/log/insurance-rag-setup.log 2>&1

echo "=== Insurance RAG EC2 Bootstrap ==="
echo "Started: $(date)"

# ── Install Docker ───────────────────────────────────────────────────
dnf update -y
dnf install -y docker git

systemctl enable docker
systemctl start docker

# Install Docker Compose v2
DOCKER_CONFIG=/usr/local/lib/docker/cli-plugins
mkdir -p $DOCKER_CONFIG
curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" \
  -o $DOCKER_CONFIG/docker-compose
chmod +x $DOCKER_CONFIG/docker-compose

# Let ec2-user run docker
usermod -aG docker ec2-user

# ── Create app directory ─────────────────────────────────────────────
APP_DIR=/opt/insurance-rag
mkdir -p $APP_DIR
cd $APP_DIR

# ── Write .env file ──────────────────────────────────────────────────
cat > .env << 'ENVEOF'
# App
APP_ENV=production
DEBUG=false
APP_NAME=Insurance RAG

# Database (local Docker container)
DATABASE_URL=postgresql+asyncpg://postgres:postgres@db:5432/insurance_rag
DATABASE_URL_SYNC=postgresql+psycopg://postgres:postgres@db:5432/insurance_rag
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=insurance_rag

# Redis (local Docker container)
REDIS_URL=redis://redis:6379/0

# API Keys
OPENAI_API_KEY=${openai_api_key}
ANTHROPIC_API_KEY=${anthropic_api_key}
PINECONE_API_KEY=${pinecone_api_key}
SECRET_KEY=${secret_key}

# Pinecone
PINECONE_INDEX_NAME=insurance-rag
PINECONE_ENVIRONMENT=us-east-1

# Embeddings
EMBEDDING_MODEL=text-embedding-3-small
EMBEDDING_DIMENSIONS=1536

# LLM
LLM_MODEL=claude-sonnet-4-20250514
LLM_PROVIDER=

# S3 (via instance role - no keys needed)
S3_BUCKET_NAME=${s3_bucket_name}
AWS_REGION=${aws_region}
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=

# CORS - CloudFront domain added after deploy
CORS_ORIGINS=*

# Rate limits
RATE_LIMIT_QUERIES=60/minute
RATE_LIMIT_UPLOADS=10/minute
RATE_LIMIT_WIDGET=30/minute
ENVEOF

# Secure the env file
chmod 600 .env

# ── Write docker-compose.yml ─────────────────────────────────────────
cat > docker-compose.yml << 'COMPOSEEOF'
services:
  db:
    image: postgres:15-alpine
    restart: always
    env_file: .env
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    restart: always
    command: redis-server --maxmemory 64mb --maxmemory-policy allkeys-lru
    volumes:
      - redisdata:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  api:
    build:
      context: .
      dockerfile: Dockerfile.prod
    restart: always
    env_file: .env
    ports:
      - "80:8000"
    volumes:
      - localstorage:/app/storage
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy

  # Watchtower auto-updates containers when you push new images
  watchtower:
    image: containrrr/watchtower
    restart: always
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: --interval 300 --cleanup
    environment:
      - WATCHTOWER_LABEL_ENABLE=false

volumes:
  pgdata:
  redisdata:
  localstorage:
COMPOSEEOF

# ── Write production Dockerfile ──────────────────────────────────────
cat > Dockerfile.prod << 'DOCKEREOF'
FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    tesseract-ocr libgl1 libglib2.0-0 curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN useradd -m appuser && mkdir -p /app/storage && chown -R appuser:appuser /app
USER appuser

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2"]
DOCKEREOF

echo "=== Bootstrap complete ==="
echo "Finished: $(date)"
echo ""
echo "Next steps:"
echo "1. SSH in: ssh ec2-user@<PUBLIC_IP>"
echo "2. Clone your repo to /opt/insurance-rag/"
echo "3. Run: cd /opt/insurance-rag && sudo docker compose up -d --build"
