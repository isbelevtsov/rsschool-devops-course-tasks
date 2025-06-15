resource "aws_security_group" "bastion_sg" {
  name        = "bastion_sg"
  description = "Security group for Bastion host SSH access"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow SSH from trusted CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(
    var.tags,
    {
      Name = "BastionSecurityGroup"
    }
  )
}

resource "aws_security_group" "vm_private_sg" {
  name        = "private_vm_sg"
  description = "Security group for private VM instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow SSH from Bastion host"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(
    var.tags,
    {
      Name = "PrivateVMSecurityGroup"
    }
  )
}
