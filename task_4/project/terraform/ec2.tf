resource "aws_instance" "k3s_control_plane" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type_cp
  subnet_id                   = aws_subnet.private[0].id
  vpc_security_group_ids      = [aws_security_group.vm_private_sg.id]
  key_name                    = var.key_pair
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.controlplane_profile.name
  user_data_replace_on_change = false

  private_dns_name_options {
    enable_resource_name_dns_a_record    = true
    enable_resource_name_dns_aaaa_record = false
    hostname_type                        = "resource-name"
  }

  root_block_device {
    encrypted   = true
    volume_size = 10
    volume_type = "gp3"
  }

  metadata_options {
    http_tokens                 = "required"
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  user_data = templatefile("${path.module}/templates/controlplane.tpl", {
    PROJECT_NAME          = var.project_name
    ENVIRONMENT_NAME      = var.environment_name
    CERT_PATH             = var.cert_path
    KEY_PARAM_PATH        = var.key_param_path
    KUBECONFIG_PARAM_PATH = var.kubeconfig_param_path
    NODE_TOKEN_PARAM_PATH = var.node_token_param_path
  })

  tags = {
    Name     = "${var.project_name}-k3s-control-plane-${var.environment_name}",
    K8s_Role = "control-plane"
  }
}

resource "aws_instance" "k3s_worker" {
  depends_on                  = [aws_instance.k3s_control_plane]
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type_worker
  subnet_id                   = aws_subnet.private[1].id
  vpc_security_group_ids      = [aws_security_group.vm_private_sg.id]
  key_name                    = var.key_pair
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.worker_profile.name
  user_data_replace_on_change = false

  private_dns_name_options {
    enable_resource_name_dns_a_record    = true
    enable_resource_name_dns_aaaa_record = false
    hostname_type                        = "resource-name"
  }

  root_block_device {
    encrypted   = true
    volume_size = 10
    volume_type = "gp3"
  }

  metadata_options {
    http_tokens                 = "required"
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  user_data = templatefile("${path.module}/templates/worker.tpl", {
    PROJECT_NAME          = var.project_name
    ENVIRONMENT_NAME      = var.environment_name
    CERT_PATH             = var.cert_path
    KEY_PARAM_PATH        = var.key_param_path
    JENKINS_DATA_DIR      = var.jenkins_data_dir
    NODE_TOKEN_PARAM_PATH = var.node_token_param_path
  })

  tags = {
    Name     = "${var.project_name}-k3s-worker-${var.environment_name}",
    K8s_Role = "worker"
  }
}

resource "aws_instance" "bastion" {
  depends_on                  = [aws_instance.k3s_control_plane, aws_instance.k3s_worker]
  ami                         = data.aws_ami.ubuntu.id # Assuming the AMI is defined in ami.tf
  instance_type               = var.instance_type_bastion
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  key_name                    = var.key_pair
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.bastion_profile.name
  user_data_replace_on_change = false

  private_dns_name_options {
    enable_resource_name_dns_a_record    = true
    enable_resource_name_dns_aaaa_record = false
    hostname_type                        = "resource-name"
  }

  root_block_device {
    encrypted   = true
    volume_size = 10
    volume_type = "gp3"
  }

  metadata_options {
    http_tokens                 = "required"
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  user_data = templatefile("${path.module}/templates/bastion.tpl", {
    PROJECT_NAME     = var.project_name
    ENVIRONMENT_NAME = var.environment_name
    CERT_PATH        = var.cert_path
    KEY_PARAM_PATH   = var.key_param_path

  })

  tags = {
    Name = "${var.project_name}-bastion-${var.environment_name}",
    Role = "bastion"
  }
}
