
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

output "public_vm_ip" {
  value = aws_instance.public_vm.public_ip
}
