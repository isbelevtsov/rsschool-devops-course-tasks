#trivy:ignore:AVD-AWS-0089
resource "aws_s3_bucket" "terraform_state" {
  bucket = var.bucket_name

  # lifecycle {
  #   prevent_destroy = true
  # }

  tags = {
    Name        = var.bucket_name
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "terraform_state_versioning" {
  depends_on = [aws_s3_bucket.terraform_state]
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state_block" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#trivy:ignore:AVD-AWS-0132
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_encryption" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Uncomment the following lines if you want to use KMS for encryption instead of AES256
# resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_encryption" {
#   bucket = aws_s3_bucket.terraform_state.id

#   rule {
#     apply_server_side_encryption_by_default {
#       sse_algorithm     = "aws:kms"
#       kms_master_key_id = aws_kms_key.terraform_state_key.arn
#     }
#   }
# }

# resource "aws_kms_key" "terraform_state_key" {
#   description             = "KMS key for encrypting Terraform state bucket"
#   deletion_window_in_days = 10
#   enable_key_rotation     = true
# }

# resource "aws_kms_alias" "terraform_state_key_alias" {
#   name          = "alias/terraform-state"
#   target_key_id = aws_kms_key.terraform_state_key.id
# }

# Uncomment the following lines if you want to enable logging for the S3 bucket
# resource "aws_s3_bucket" "log_bucket" {
#   bucket = "${var.bucket_name}-logs"

#   tags = {
#     Name = "${var.bucket_name}-logs"
#   }
# }

# resource "aws_s3_bucket_logging" "terraform_state_logging" {
#   bucket = aws_s3_bucket.terraform_state.id

#   target_bucket = aws_s3_bucket.log_bucket.id
#   target_prefix = "logs/"
#   depends_on = [aws_s3_bucket.log_bucket]
# }
