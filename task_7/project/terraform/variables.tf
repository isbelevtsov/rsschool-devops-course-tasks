variable "aws_region" {
  default     = "eu-north-1"
  type        = string
  description = "AWS region to deploy resources in"
}

variable "aws_account_id" {
  description = "AWS Account ID (used for GitHub OIDC trust)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "List of availability zones for the region"
  type        = list(string)
  default     = ["eu-north-1a", "eu-north-1b"]
}

variable "instance_type_bastion" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.nano"
}

variable "instance_type_cp" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "instance_type_worker" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into bastion"
  type        = string
  default     = "0.0.0.0/0"
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "environment_name" {
  description = "Environment for the deployment (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "rs"
}

variable "route53_domain" {
  description = "Domain name for Route 53 DNS records"
  type        = string
  default     = "aws.elysium-space.com"
}

variable "jenkins_data_dir" {
  description = "Persistent data directory for Jenkins"
  type        = string
  default     = "/data/jenkins"
}
