data "aws_ssm_parameter" "ssh_key" {
  name            = var.param_name
  with_decryption = true
}

resource "local_file" "ssh_key" {
  content         = data.aws_ssm_parameter.ssh_key.value
  filename        = "${path.module}/${var.key_pair}.pem"
  file_permission = "0600"
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.ubuntu.id # Assuming the AMI is defined in ami.tf
  instance_type               = var.instance_type_bastion
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  key_name                    = var.key_pair
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name
  user_data_replace_on_change = true

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

resource "aws_instance" "k3s_control_plane" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type_cp
  subnet_id                   = aws_subnet.private[0].id
  vpc_security_group_ids      = [aws_security_group.vm_private_sg.id]
  key_name                    = var.key_pair
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name

  root_block_device {
    encrypted   = true  # Ensure encryption at rest
    volume_size = 10    # Optional: override size in GiB
    volume_type = "gp3" # Optional: specify EBS volume type
  }

  metadata_options {
    http_tokens                 = "required" # Enforce IMDSv2
    http_endpoint               = "enabled"  # Optional but recommended
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  tags = {
    Name = "${var.project_name}-k3s-control-plane-${var.environment_name}"
  }
}

resource "null_resource" "provision_k3s_control_plane" {
  depends_on = [local_file.ssh_key, aws_instance.bastion, aws_instance.k3s_control_plane, aws_nat_gateway.natgw]

  provisioner "remote-exec" {
    connection {
      type                = "ssh"
      host                = aws_instance.k3s_control_plane.private_ip
      user                = "ubuntu"
      private_key         = file(local_file.ssh_key.filename)
      bastion_host        = aws_instance.bastion.public_ip
      bastion_user        = "ubuntu"
      bastion_private_key = file(local_file.ssh_key.filename)
    }
    when = create

    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y awscli",
      "export AWS_DEFAULT_REGION=\"${var.aws_region}\"",
      "curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC='--write-kubeconfig-mode 644' sh -",
      "aws ssm put-parameter --name \"${var.kubeconfig_param_path}\" --value file:///etc/rancher/k3s/k3s.yaml --type SecureString"
    ]
  }
}


resource "aws_instance" "k3s_worker" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type_worker
  subnet_id                   = aws_subnet.private[1].id
  vpc_security_group_ids      = [aws_security_group.vm_private_sg.id]
  key_name                    = var.key_pair
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name

  root_block_device {
    encrypted   = true  # Ensure encryption at rest
    volume_size = 10    # Optional: override size in GiB
    volume_type = "gp3" # Optional: specify EBS volume type
  }

  metadata_options {
    http_tokens                 = "required" # Enforce IMDSv2
    http_endpoint               = "enabled"  # Optional but recommended
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  tags = {
    Name = "${var.project_name}-k3s-worker-${var.environment_name}"
  }
}

resource "null_resource" "provision_k3s_worker" {
  depends_on = [local_file.ssh_key, aws_instance.bastion, aws_instance.k3s_control_plane, null_resource.provision_k3s_control_plane, aws_nat_gateway.natgw]

  provisioner "remote-exec" {
    connection {
      type                = "ssh"
      host                = aws_instance.k3s_worker.private_ip
      user                = "ubuntu"
      private_key         = file(local_file.ssh_key.filename)
      bastion_host        = aws_instance.bastion.public_ip
      bastion_user        = "ubuntu"
      bastion_private_key = file(local_file.ssh_key.filename)
    }
    when = create

    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y awscli",
      "export AWS_DEFAULT_REGION=\"${var.aws_region}\"",
      "aws ssm get-parameter --name \"${var.param_name}\" --with-decryption --query \"Parameter.Value\" --output text > ${local_file.ssh_key.filename}",
      "sudo chmod 600 ${local_file.ssh_key.filename}",
      "ls -lah ${local_file.ssh_key.filename}",
      "export K3S_TOKEN=$(ssh -o StrictHostKeyChecking=no -i ${local_file.ssh_key.filename} ubuntu@${aws_instance.k3s_control_plane.private_ip} 'sudo cat /var/lib/rancher/k3s/server/node-token')",
      "export K3S_URL=https://${aws_instance.k3s_control_plane.private_ip}:6443",
      "curl -sfL https://get.k3s.io | sh -"
    ]
  }
}

# resource "null_resource" "delete_key_file" {
#   depends_on = [null_resource.provision_k3s_control_plane, null_resource.provision_k3s_worker]

#   provisioner "local-exec" {
#     command = "if [ -f '${local_file.ssh_key.filename}' ]; then rm -f '${local_file.ssh_key.filename}'; fi"
#   }
# }
