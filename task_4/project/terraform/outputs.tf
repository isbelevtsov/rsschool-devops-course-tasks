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
