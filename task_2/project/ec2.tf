resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.ubuntu.id # Assuming the AMI is defined in ami.tf
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  key_name                    = var.key_pair
  associate_public_ip_address = true

  root_block_device {
    encrypted   = true  # Ensure encryption at rest
    volume_size = 8     # Optional: override size in GiB
    volume_type = "gp3" # Optional: specify EBS volume type
  }

  metadata_options {
    http_tokens   = "required" # Enforce IMDSv2
    http_endpoint = "enabled"  # Optional but recommended
  }

  tags = {
    Name = "BastionHost"
  }
}

resource "aws_instance" "private_vm" {
  count                       = length(var.private_subnet_cidrs)
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.private[count.index].id
  vpc_security_group_ids      = [aws_security_group.vm_private_sg.id]
  key_name                    = var.key_pair
  associate_public_ip_address = false

  root_block_device {
    encrypted   = true  # Ensure encryption at rest
    volume_size = 8     # Optional: override size in GiB
    volume_type = "gp3" # Optional: specify EBS volume type
  }

  metadata_options {
    http_tokens   = "required" # Enforce IMDSv2
    http_endpoint = "enabled"  # Optional but recommended
  }

  tags = {
    Name = "PrivateVM-${count.index + 1}"
  }
}

resource "aws_instance" "public_vm" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[1].id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  key_name                    = var.key_pair
  associate_public_ip_address = true

  root_block_device {
    encrypted   = true  # Ensure encryption at rest
    volume_size = 8     # Optional: override size in GiB
    volume_type = "gp3" # Optional: specify EBS volume type
  }

  metadata_options {
    http_tokens   = "required" # Enforce IMDSv2
    http_endpoint = "enabled"  # Optional but recommended
  }

  tags = {
    Name = "PublicVM"
  }
}
