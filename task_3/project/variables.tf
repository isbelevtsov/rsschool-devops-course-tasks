variable "aws_region" {
  default     = "eu-north-1"
  type        = string
  description = "AWS region to deploy resources in"
}

variable "aws_account_id" {
  type        = string
  description = "AWS Account ID (used for GitHub OIDC trust)"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "azs" {
  type        = list(string)
  description = "List of availability zones for the region"
  default     = ["eu-north-1a", "eu-north-1b"]
}

variable "instance_type_bastion" {
  description = "EC2 instance type"
  default     = "t3.nano"
  type        = string
}

variable "instance_type_cp" {
  description = "EC2 instance type"
  default     = "t3.medium"
  type        = string
}

variable "instance_type_worker" {
  description = "EC2 instance type"
  default     = "t3.small"
  type        = string
}

variable "key_pair" {
  description = "EC2 key pair name"
  type        = string
  default     = "blackbird"
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into bastion"
  type        = string
  default     = "0.0.0.0/0"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks for public subnets"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks for private subnets"
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

variable "cert_path" {
  description = "Path to the certificate file"
  type        = string
  default     = "/home/ubuntu/cert.pem"
}

variable "key_param_path" {
  description = "Parameter name for the SSH certificate in SSM"
  type        = string
  default     = "/ec2/cert.pem"
}

variable "kubeconfig_param_path" {
  description = "Path to the kubeconfig parameter in SSM"
  type        = string
  default     = "/ec2/kubeconfig"
}
