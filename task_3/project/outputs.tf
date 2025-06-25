output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "k3s_control_plane_ip" {
  value = aws_instance.k3s_control_plane.private_ip
}

output "k3s_worker_ip" {
  value = aws_instance.k3s_worker.private_ip
}
