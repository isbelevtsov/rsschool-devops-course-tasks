resource "aws_iam_user" "github_action_user" {
  name = var.user_name
}
resource "aws_iam_access_key" "github_action_user_key" {
  count = var.create_access_key ? 1 : 0
  user  = aws_iam_user.github_action_user.name
}
