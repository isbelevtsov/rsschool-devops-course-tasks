resource "aws_kms_key" "cloudwatch" {
  description         = "KMS key for encrypting VPC flow logs"
  enable_key_rotation = true

  tags = merge(
    var.tags,
    {
      Name = "CloudWatchKMSKey"
    }
  )
}
