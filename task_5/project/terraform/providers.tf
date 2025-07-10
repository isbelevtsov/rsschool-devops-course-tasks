terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0.0"
    }
    template = {
      source  = "hashicorp/template"
      version = "~> 2.2.0"
    }
  }

  backend "s3" {
    bucket       = "rsschool-bootstrap-terraform-state"
    key          = "global/rsschool/terraform-project.tfstate"
    region       = "eu-north-1"
    encrypt      = true
    use_lockfile = true
  }

  required_version = ">= 1.3.0"
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      "Course"      = "RSSchool DevOps Course"
      "Task"        = "5. Simple Application Deployment with Helm"
      "ManagedBy"   = "Terraform"
      "CI"          = "GitHub Actions"
      "Date"        = "2025-07-08"
      "Project"     = "rs"
      "Environment" = "dev"
    }
  }
}
