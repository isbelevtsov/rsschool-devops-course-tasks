output "bastion_sg_id" {
  description = "Bastion host security group ID"
  value       = aws_security_group.bastion_sg.id
}

output "bastion_public_ip" {
  description = "Bastion host public IP address"
  value       = aws_instance.bastion.public_ip
}

output "k3s_control_plane_private_ip" {
  description = "K3s control plane node host private IP address"
  value       = aws_instance.k3s_control_plane.private_ip
}

output "k3s_worker_private_ip" {
  description = "K3s worker node host private IP address"
  value       = aws_instance.k3s_worker.private_ip
}

output "ses_domain_identity_verification_token" {
  description = "value of the SES domain identity verification token"
  value       = aws_ses_domain_identity.monitoring_email.verification_token
}

output "ses_smtp_endpoint" {
  description = "SMTP endpoint for SES"
  value       = "email-smtp.${var.aws_region}.amazonaws.com:587"
}

output "grafana_smtp_username" {
  description = "Grafana SMTP username stored in SSM Parameter Store"
  value       = aws_ssm_parameter.grafana_smtp_username.value
  sensitive   = true
}

output "grafana_smtp_user_key" {
  description = "Grafana SMTP user key stored in SSM Parameter Store"
  value       = aws_ssm_parameter.grafana_smtp_user_key.value
  sensitive   = true
}

output "grafana_smtp_password" {
  description = "Grafana SMTP password stored in SSM Parameter Store"
  value       = data.external.generate_smtp_password.result.smtp_password
  sensitive   = true
}

output "aws_iam_smtp_password_v4" {
  description = "AWS IAM SMTP password v4 for SES"
  value       = aws_iam_access_key.grafana_smtp_user_key.ses_smtp_password_v4
  sensitive   = true
}
