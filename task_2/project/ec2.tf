resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.ubuntu.id # Assuming the AMI is defined in ami.tf
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  key_name                    = var.key_pair
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name

  user_data = templatefile("${path.module}/user_data.tpl", {
    CERT_PATH  = var.cert_path
    PARAM_NAME = var.param_name
  })

  root_block_device {
    encrypted   = true  # Ensure encryption at rest
    volume_size = 8     # Optional: override size in GiB
    volume_type = "gp3" # Optional: specify EBS volume type
  }

  metadata_options {
    http_tokens                 = "required" # Enforce IMDSv2
    http_endpoint               = "enabled"  # Optional but recommended
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  tags = {
    Name = "${var.project_name}-bastion-${var.environment_name}"
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
    http_tokens                 = "required" # Enforce IMDSv2
    http_endpoint               = "enabled"  # Optional but recommended
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  tags = {
    Name = "${var.project_name}-vm-private-${var.environment_name}-${count.index + 1}"
  }
}

resource "aws_instance" "public_vm" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[1].id
  vpc_security_group_ids      = [aws_security_group.vm_public_sg.id]
  key_name                    = var.key_pair
  associate_public_ip_address = true

  root_block_device {
    encrypted   = true  # Ensure encryption at rest
    volume_size = 8     # Optional: override size in GiB
    volume_type = "gp3" # Optional: specify EBS volume type
  }

  metadata_options {
    http_tokens                 = "required" # Enforce IMDSv2
    http_endpoint               = "enabled"  # Optional but recommended
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  tags = {
    Name = "${var.project_name}-vm-public-${var.environment_name}"
  }
}
