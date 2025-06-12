output "iam_user_name" {
  value = aws_iam_user.rsschool_user.name
}

output "iam_access_key_id" {
  value     = aws_iam_access_key.rsschool_user_key[0].id
  sensitive = true
}

output "iam_secret_access_key" {
  value     = aws_iam_access_key.rsschool_user_key[0].secret
  sensitive = true
}

output "aws_region" {
  value = var.aws_region
}
