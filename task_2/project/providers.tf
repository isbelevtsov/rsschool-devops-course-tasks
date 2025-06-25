terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.3.0"
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      "Course"    = "RSSchool DevOps Course"
      "Task"      = "2. Basic Infrastructure Configuration"
      "ManagedBy" = "Terraform"
      "CI"        = "GitHub Actions"
      "Date"      = "2025-06-19"
    }
  }
}
