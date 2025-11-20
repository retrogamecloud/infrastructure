terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Este terraform usa backend local (terraform.tfstate en disco)
  # No necesita backend remoto porque ES el que crea la infraestructura base
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform-Bootstrap"
      Purpose     = "Terraform State Backend"
    }
  }
}
