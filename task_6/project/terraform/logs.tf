
# AVD-AWS-0017 (LOW)
# See https://avd.aquasec.com/misconfig/avd-aws-0017
resource "aws_kms_key" "cloudwatch" {
  description         = "KMS key for encrypting VPC flow logs"
  enable_key_rotation = true

  tags = {
    Name = "${var.project_name}-kms-key-cloudwatch-${var.environment_name}"
  }
}

# resource "aws_kms_key_policy" "cloudwatch" {
#   key_id = aws_kms_key.cloudwatch.id
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Id      = "key-default-1"
#     Statement = [
#       {
#         Sid    = "Enable IAM User Permissions"
#         Effect = "Allow"
#         Principal = {
#           AWS = "arn:aws:iam::${var.aws_account_id}:root",
#         },
#         Action   = "kms:*"
#         Resource = "*"
#       },
#       {
#         Sid    = "Enable IAM User Permissions"
#         Effect = "Allow"
#         Principal = {
#           AWS = "arn:aws:iam::${var.aws_account_id}:ow1eye",
#         },
#         Action   = "kms:*"
#         Resource = "*"
#       },
#       {
#         Sid    = "Enable IAM User Permissions"
#         Effect = "Allow"
#         Principal = {
#           AWS = "arn:aws:iam::${var.aws_account_id}:role/GithubActionRole",
#         },
#         Action   = "kms:*"
#         Resource = "*"
#       }
#     ]
#   })
# }

# AVD-AWS-0017 (LOW)
# See https://avd.aquasec.com/misconfig/avd-aws-0017
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flow-logs"
  retention_in_days = 30
  skip_destroy      = false
  # kms_key_id        = aws_kms_key.cloudwatch.key_id

  tags = {
    Name = "${var.project_name}-vpc-flow-log-group-${var.environment_name}"
  }
}

# AVD-AWS-0178 (MEDIUM)
# See https://avd.aquasec.com/misconfig/aws-autoscaling-enable-at-rest-encryption
resource "aws_flow_log" "vpc_flow" {
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  log_destination_type = "cloud-watch-logs"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.main.id
  iam_role_arn         = aws_iam_role.vpc_flow_logs_role.arn

  tags = {
    Name = "${var.project_name}-vpc-flow-logs-${var.environment_name}"
  }
}
