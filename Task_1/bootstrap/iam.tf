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
    sid    = "DenyAllExceptForMFA"
    effect = "Deny"

    actions = ["*"]
    resources = ["*"]

    condition {
      test     = "BoolIfExists"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["false"]
    }
  }
}

resource "aws_iam_policy" "mfa_enforce" {
  name        = "${var.group_name}-mfa-enforce"
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
