terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state in S3 with DynamoDB locking
  # Local: terraform init -backend-config=backend-local.hcl
  # CI:    terraform init (uses AWS env vars)
  backend "s3" {
    bucket         = "insurance-rag-tfstate"
    key            = "infra/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "insurance-rag-tflock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  # When running locally, set TF_VAR_aws_profile=insurance-rag
  # In CI, leave empty — GitHub Actions sets AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY
  profile = var.aws_profile != "" ? var.aws_profile : null

  default_tags {
    tags = {
      Project     = "insurance-rag"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

provider "aws" {
  alias   = "us_east_1"
  region  = "us-east-1"
  profile = var.aws_profile != "" ? var.aws_profile : null
}
