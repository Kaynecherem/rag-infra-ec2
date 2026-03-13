variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile name (leave empty in CI)"
  type        = string
  default     = ""
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "insurance-rag"
}

variable "domain_name" {
  description = "Custom domain name"
  type        = string
  default     = "agencylensai.com"
}

variable "ec2_instance_type" {
  description = "EC2 instance type (t2.micro = free tier)"
  type        = string
  default     = "t3.micro"
}

variable "ssh_key_name" {
  description = "Name of the EC2 key pair for SSH access"
  type        = string
}

variable "my_ip" {
  description = "Your IP for SSH access (e.g. 1.2.3.4/32). Use 0.0.0.0/0 if unsure."
  type        = string
  default     = "0.0.0.0/0"
}

# ── API Keys (stored in .env on EC2) ─────────────────────────────────

variable "openai_api_key" {
  type      = string
  sensitive = true
}

variable "anthropic_api_key" {
  type      = string
  sensitive = true
}

variable "pinecone_api_key" {
  type      = string
  sensitive = true
}

variable "secret_key" {
  description = "JWT signing key — must match across client-backend and superadmin-backend"
  type        = string
  sensitive   = true
}

# ── Auth0 ─────────────────────────────────────────────────────────────

variable "auth0_domain" {
  description = "Auth0 tenant domain"
  type        = string
  default     = "insurance-rag.us.auth0.com"
}

variable "auth0_audience" {
  description = "Auth0 API audience"
  type        = string
  default     = "https://api.insurance-rag.com"
}
