resource "aws_ses_domain_identity" "monitoring_email" {
  domain = var.route53_domain
}

resource "aws_ses_domain_dkim" "monitoring_email" {
  domain = aws_ses_domain_identity.monitoring_email.domain
}

resource "aws_ses_domain_mail_from" "monitoring_email" {
  domain           = aws_ses_domain_identity.monitoring_email.domain
  mail_from_domain = "bounce.${aws_ses_domain_identity.monitoring_email.domain}"
}

resource "aws_ses_email_identity" "monitoring_email" {
  email = var.verified_email
}

# Use this block to create the SES identity mail from configuration instead of the domain mail from configuration
# resource "aws_ses_domain_mail_from" "monitoring_email" {
#   domain           = aws_ses_email_identity.monitoring_email.email
#   mail_from_domain = "monitoring@${var.route53_domain}"
# }

data "external" "generate_smtp_password" {
  program = ["${path.module}/templates/generate_smtp_password.py"]

  query = {
    secret = aws_iam_access_key.grafana_smtp_user_key.secret
  }
}

resource "aws_ssm_parameter" "grafana_smtp_username" {
  depends_on = [aws_iam_user.grafana_smtp_user]
  name       = "/${var.project_name}/${var.environment_name}/kube/grafana/smtp_username"
  type       = "String"
  value      = aws_iam_user.grafana_smtp_user.name
}

resource "aws_ssm_parameter" "grafana_smtp_user_key" {
  depends_on = [aws_iam_access_key.grafana_smtp_user_key]
  name       = "/${var.project_name}/${var.environment_name}/kube/grafana/smtp_user_key"
  type       = "SecureString"
  value      = aws_iam_access_key.grafana_smtp_user_key.id
}

resource "aws_ssm_parameter" "grafana_smtp_password" {
  depends_on = [data.external.generate_smtp_password]
  name       = "/${var.project_name}/${var.environment_name}/kube/grafana/smtp_password"
  type       = "SecureString"
  value      = data.external.generate_smtp_password.result.smtp_password
}

resource "aws_ssm_parameter" "grafana_smtp_host" {
  name  = "/${var.project_name}/${var.environment_name}/kube/grafana/smtp_host"
  type  = "String"
  value = "email-smtp.${var.aws_region}.amazonaws.com:587"
}

resource "aws_ssm_parameter" "grafana_smtp_from_address" {
  name  = "/${var.project_name}/${var.environment_name}/kube/grafana/from_address"
  type  = "String"
  value = aws_ses_email_identity.monitoring_email.email
}

resource "aws_ssm_parameter" "grafana_smtp_password_v4" {
  depends_on = [aws_iam_access_key.grafana_smtp_user_key]
  name       = "/${var.project_name}/${var.environment_name}/kube/grafana/smtp_password_v4"
  type       = "SecureString"
  value      = aws_iam_access_key.grafana_smtp_user_key.ses_smtp_password_v4
}
