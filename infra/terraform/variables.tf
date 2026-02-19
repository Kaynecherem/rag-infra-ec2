variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
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
  description = "JWT signing key"
  type        = string
  sensitive   = true
}
