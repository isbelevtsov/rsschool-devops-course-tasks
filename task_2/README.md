# Tasks 2: Basic Infrastructure Configuration

[![Terraform Plan and Apply](https://github.com/isbelevtsov/rsschool-devops-course-tasks/actions/workflows/terraform.yml/badge.svg)](https://github.com/isbelevtsov/rsschool-devops-course-tasks/actions/workflows/terraform.yml)

## Overview

This project sets up a basic AWS infrastructure using Terraform and GitHub Actions.

## Prerequisites

- Task 1 bootstrap Terraform code must be executed before running this task.
- Github Action Secrets must be already initialized throught the Github web console.
- Set variables according to your desire.

## Features

- VPC creation with CIDR block `10.0.0.0/16`
- 2 Public subnets in separate Availability Zones
- 2 Private subnets in separate Availability Zones
- Internet Gateway for public subnet access
- Route tables for intra-VPC and external access
- Bastion EC2 instance in the public subnet
- Pablic EC2 instance in the public subnet
- Private EC2 instances in private subnets
- Security Groups with descriptions and rule auditing
- Network Access Lists for better subnet traffic control
- CloudWatch log group for VPC flow logs
- Tags including GitHub Actions metadata
- GitHub Actions pipeline for Terraform Plan, Apply & Destroy using OIDC

## Directory Structure

```
.
├── .github
│   └── workflows
│       └── terraform.yml                   # Github Actions workflow pipeline configuration
├── task_2
│   ├── project
│   │    ├── .env.example                    # Example file contains variables for Makefile
│   │    ├── ami.tf                          # AWS AMI configuration for future EC2 instaces deployment
│   │    ├── backend.tf                      # Terraform backend condiguration
│   │    ├── ec2.tf                          # AWS EC2 instances configuration
│   │    ├── iam.tf                          # AWS IAM configuration
│   │    ├── logs.tf                         # AWS S3 bucket logging for security purpose and KMS key configuration for data encryption
│   │    ├── Makefile                        # Makefile for better project and data magement
│   │    ├── networking.tf                   # AWS subnets and routing configuration alongside with network access lists configuration
│   │    ├── outputs.tf                      # Terraform outputs data
│   │    ├── providers.tf                    # Terraform providers configuration
│   │    ├── sg.tf                           # AWS security groups configuration for network traffic control
│   │    ├── terraform.auto.tfvars.example   # Example file contains test variables or placeholders for Terraform (only for local usage, \
│   │    │                                     Github Actions workflow will generate it in process)
│   │    ├── variables.tf                    # Terraform variables configuration
│   │    └── vpc.tf                          # AWS VPC configuration
│   └── README.md                            # This file
```

## GitHub Actions Workflow

The `terraform.yml` workflow performs:

- Code checkout
- Terraform setup
- AWS credentials via OIDC
- `terraform fmt`, `init`, `plan`, `apply`, `destroy`
- PR comment with `terraform plan` output

## Required GitHub Secrets

| Secret Name            | Description                      |
|------------------------|----------------------------------|
| `TF_VERSION`           | Terraform version                |
| `AWS_REGION`           | AWS region                       |
| `AWS_ACCOUNT_ID`       | AWS account ID                   |
| `VPC_CIDR`             | VPC CIDR block                   |
| `AZS`                  | Comma-separated AZ list          |
| `PUBLIC_SUBNET_CIDRS`  | Comma-separated CIDRs for public |
| `PRIVATE_SUBNET_CIDRS` | Comma-separated CIDRs for private|
| `ALLOWED_SSH_CIDR`     | CIDR block for SSH access        |
| `KEY_PAIR`             | EC2 key pair name                |
| `GH_TOKEN`             | Github token for commenting PR   |

## Security Best Practices Implemented

- IMDSv2 enforcement for EC2 (AVD-AWS-0028)
- Encrypted root EBS volumes (AVD-AWS-0131)
- Security group and rule descriptions (AVD-AWS-0099, AVD-AWS-0124)
- VPC Flow Logs enabled (AVD-AWS-0178)
- CloudWatch Log Group encryption awareness (AVD-AWS-0017)

## Terraform Version

Tested with Terraform `1.12.0`

## Notes

- All tagging includes `Task`, `ManagedBy`, `CI`, and `Date` fields.
- `output.tfplan` is commented on PRs automaticaly.
- All resources can be destroyed using the same way as `Plan` or `Apply`.

## Usability confirmation
