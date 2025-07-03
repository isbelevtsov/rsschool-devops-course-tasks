terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0.0"
    }
  }

  required_version = ">= 1.3.0"
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      "Course"    = "RSSchool DevOps Course"
      "Task"      = "3. K8s Cluster Configuration and Creation"
      "ManagedBy" = "Terraform"
      "CI"        = "GitHub Actions"
      "Date"      = "2025-06-25"
    }
  }
}
