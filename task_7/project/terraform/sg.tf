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

  ingress {
    description = "Allow HTTP from trusted CIDR"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Needed for GitHub Webhook to work with Jenkins
  }

  ingress {
    description = "Allow HTTPS from trusted CIDR"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Needed for GitHub Webhook to work with Jenkins
  }

  ingress {
    description = "Allow kubernetes API from trusted CIDR"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description = "Allow all from VPC CIDR"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
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

resource "aws_security_group" "vm_public_sg" {
  name        = "${var.project_name}-sg-public-vm-${var.environment_name}"
  description = "Security group for public VM instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow all inbound traffic from the internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow all from VPC CIDR"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
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
    description = "Allow all VPC CIDR traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
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
