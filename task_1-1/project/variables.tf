variable "aws_region" {
  default     = "eu-north-1"
  type        = string
  description = "AWS region to deploy resources in"
}

variable "aws_account_id" {
  type        = string
  description = "AWS Account ID (used for GitHub OIDC trust)"
}

variable "user_name" {
  description = "IAM user name"
  type        = string
}

variable "create_access_key" {
  description = "Whether to create an access key for the user"
  type        = bool
  default     = true
}
