resource "aws_security_group" "bastion_sg" {
  name        = "${var.project_name}-sg-bastion-${var.environment_name}"
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
  tags = {
    Name = "${var.project_name}-sg-bastion-${var.environment_name}"
  }
}

resource "aws_security_group" "public_vm_sg" {
  name        = "${var.project_name}-sg-public-vm-${var.environment_name}"
  description = "Security group for public VM instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow all inbound traffic from the internet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.project_name}-sg-public-vm-${var.environment_name}"
  }
}

resource "aws_security_group" "vm_private_sg" {
  name        = "${var.project_name}-sg-private-vm-${var.environment_name}"
  description = "Security group for private VM instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow all from Bastion host"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.project_name}-sg-private-vm-${var.environment_name}"
  }
}
