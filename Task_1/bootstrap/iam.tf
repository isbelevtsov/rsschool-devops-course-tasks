locals {
  role_name = "GithubActionRole"
}

resource "aws_iam_user" "rsschool_user" {
  name = var.user_name
}

resource "aws_iam_access_key" "rsschool_user_key" {
  count = var.create_access_key ? 1 : 0
  user  = aws_iam_user.rsschool_user.name
}

resource "aws_iam_group" "rsschool_group" {
  name = var.group_name
}

data "aws_iam_policy_document" "mfa_enforce_policy" {
  statement {
    sid    = "DenyAllExceptS3WithoutMFA"
    effect = "Deny"

    not_actions = [
      "s3:*",
      "iam:Get*",
      "iam:List*",
      "iam:CreateOpenIDConnectProvider",
      "iam:TagOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
      "iam:CreateRole",
      "iam:PassRole",
      "iam:DeleteRole",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy"
    ]
    resources = ["*"]

    condition {
      test     = "BoolIfExists"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["false"]
    }
  }
}

resource "aws_iam_policy" "mfa_enforce" {
  name        = "${var.group_name}_mfa_enforce"
  description = "Enforce MFA for group ${var.group_name}"
  policy      = data.aws_iam_policy_document.mfa_enforce_policy.json
}

resource "aws_iam_group_policy_attachment" "mfa_enforce_attach" {
  group      = aws_iam_group.rsschool_group.name
  policy_arn = aws_iam_policy.mfa_enforce.arn
}

resource "aws_iam_group_policy_attachment" "rsschool_group_policy_attachments" {
  for_each = toset(var.managed_policy_arns)

  group      = aws_iam_group.rsschool_group.name
  policy_arn = each.key
}

resource "aws_iam_user_group_membership" "rsschool_user_group_membership" {
  user   = aws_iam_user.rsschool_user.name
  groups = [aws_iam_group.rsschool_group.name]
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
  name = local.role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_oidc.arn
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
  depends_on = [aws_iam_openid_connect_provider.github_oidc]
}

resource "aws_iam_role_policy_attachment" "github_action_role_attachment" {
  for_each   = toset(var.managed_policy_arns)
  role       = aws_iam_role.github_action_role.name
  policy_arn = each.key
}
