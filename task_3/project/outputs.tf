
output "aws_region" {
  value = var.aws_region
}

output "aws_account_id" {
  value     = var.aws_account_id
  sensitive = true
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "k3s_control_plane_ip" {
  value = aws_instance.k3s_control_plane.private_ip
}

output "k3s_worker_ips" {
  value = aws_instance.k3s_worker[*].private_ip
}

output "bastion_instance_id" {
  value = aws_instance.bastion.id
}

output "k3s_control_plane_instance_id" {
  value = aws_instance.k3s_control_plane.id
}

output "k3s_worker_instance_ids" {
  value = aws_instance.k3s_worker[*].id
}

output "kubeconfig" {
  value = aws_instance.k3s_control_plane.user_data // if config written locally
}
