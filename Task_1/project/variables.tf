variable "aws_region" {
  default     = "eu-north-1"
  type        = string
  description = "AWS region to deploy resources in"
}

variable "managed_policy_arns" {
  description = "List of AWS managed policy ARNs to attach to the group"
  type        = list(string)
  default     = []
}

variable "aws_account_id" {
  type        = string
  description = "AWS Account ID (used for GitHub OIDC trust)"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name in 'owner/repo' format"
}

# variable "create_role" {
#   description = "Whether to create an IAM role"
#   type        = bool
#   default     = false
# }

# variable "bucket_name" {
#   description = "S3 bucket name for Terraform state"
#   type        = string
# }

# variable "environment" {
#   type        = string
#   default     = "dev"
#   description = "Environment name (used in tagging)"
# }

# variable "user_name" {
#   description = "IAM user name"
#   type        = string
# }

# variable "create_access_key" {
#   description = "Whether to create an access key for the user"
#   type        = bool
#   default     = true
# }
