variable "aws_region" {
  default     = "eu-north-1"
  type        = string
  description = "AWS region to deploy resources in"
}

variable "aws_profile" {
  description = "AWS profile to use for authentication"
  type        = string
  default     = "default"
}

variable "user_name" {
  description = "IAM user name"
  type        = string
}

variable "group_name" {
  description = "IAM group name"
  type        = string
}

variable "create_access_key" {
  description = "Whether to create an access key for the user"
  type        = bool
  default     = true
}

variable "bucket_name" {
  description = "S3 bucket name for Terraform state"
  type        = string
  default     = "rsschool-bootstrap-terraform-state"
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Environment name (used in tagging)"
}

variable "managed_policy_arns" {
  description = "List of AWS managed policy ARNs to attach to the group"
  type        = list(string)
  default     = []
}
