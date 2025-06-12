output "github_action_user_name" {
  value = aws_iam_user.github_action_user.name
}

output "github_action_user_access_key_id" {
  value     = aws_iam_access_key.github_action_user_key[0].id
  sensitive = true
}

output "github_action_user_secret_access_key" {
  value     = aws_iam_access_key.github_action_user_key[0].secret
  sensitive = true
}

output "aws_region" {
  value = var.aws_region
}

output "aws_account_id" {
  value     = var.aws_account_id
  sensitive = true
}
