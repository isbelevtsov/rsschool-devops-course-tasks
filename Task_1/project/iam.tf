locals {
    role_name = "GithubActionRole"
}

resource "aws_iam_openid_connect_provider" "github_oidc" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1" # GitHub's public root cert thumbprint
  ]
}

resource "aws_iam_role" "github_action_role" {
  name               = local.role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = "arn:aws:iam::${var.aws_account_id}:oidc-provider/token.actions.githubusercontent.com"
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          },
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
          }
        }
      }
    ]
  })
  depends_on = [ aws_iam_openid_connect_provider.github_oidc ]
}

resource "aws_iam_role_policy_attachment" "github_action_role_attachment" {
  for_each = toset(var.managed_policy_arns)
  role       = aws_iam_role.github_action_role.name
  policy_arn = each.key
}

# resource "aws_iam_user" "github_action_user" {
#   name = var.user_name
# }
# resource "aws_iam_access_key" "github_action_user_key" {
#   count = var.create_access_key ? 1 : 0
#   user  = aws_iam_user.github_action_user.name
# }
