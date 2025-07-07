data "aws_ssm_parameter" "ssh_key" {
  name            = var.key_param_path
  with_decryption = true
}

resource "local_file" "ssh_key" {
  content         = data.aws_ssm_parameter.ssh_key.value
  filename        = "${path.module}/${var.key_pair}.pem"
  file_permission = "0600"
}

resource "aws_instance" "bastion" {
  depends_on                  = [local_file.ssh_key]
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type_bastion
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  key_name                    = var.key_pair
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.bastion_profile.name
  user_data_replace_on_change = true

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

  user_data = templatefile("${path.module}/templates/bastion.sh", {
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

resource "null_resource" "wait_for_health_check_bastion" {
  depends_on = [aws_instance.bastion]

  provisioner "local-exec" {
    command = <<-EOT
      INSTANCE_ID="${aws_instance.bastion.id}"
      STATUS=$(aws ec2 describe-instance-status --instance-ids $INSTANCE_ID --query "InstanceStatuses[0].InstanceStatus.Status" --output text)

      while [ "$STATUS" != "ok" ]; do
        echo "Waiting for instance health check to pass..."
        sleep 10
        STATUS=$(aws ec2 describe-instance-status --instance-ids $INSTANCE_ID --query "InstanceStatuses[0].InstanceStatus.Status" --output text)
      done
      echo "Instance health check passed!"
    EOT
  }
}

resource "null_resource" "provision_bastion" {
  depends_on = [null_resource.wait_for_health_check_bastion]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = aws_instance.bastion.public_ip
      user        = "ubuntu"
      private_key = file(local_file.ssh_key.filename)
    }
    when = create

    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y awscli",
      # "sudo systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service && sudo systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service",
      "export AWS_DEFAULT_REGION='${var.aws_region}'",
      "aws ssm get-parameter --name '${var.key_param_path}' --with-decryption --query \"Parameter.Value\" --output text > ${local_file.ssh_key.filename}",
      "sudo chmod 600 ${local_file.ssh_key.filename}"
    ]
  }
}

resource "aws_instance" "k3s_control_plane" {
  depends_on = [
    local_file.ssh_key,
    null_resource.provision_bastion,
    aws_nat_gateway.natgw
  ]
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type_cp
  subnet_id                   = aws_subnet.private[0].id
  vpc_security_group_ids      = [aws_security_group.vm_private_sg.id]
  key_name                    = var.key_pair
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.controlplane_profile.name
  user_data_replace_on_change = true

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

  user_data = templatefile("${path.module}/templates/controlplane.sh", {
    PROJECT_NAME     = var.project_name
    ENVIRONMENT_NAME = var.environment_name
    CERT_PATH        = var.cert_path
    KEY_PARAM_PATH   = var.key_param_path
  })

  tags = {
    Name     = "${var.project_name}-k3s-control-plane-${var.environment_name}",
    K8s_Role = "control-plane"
  }
}

resource "null_resource" "wait_for_health_check_k3s_control_plane" {
  depends_on = [aws_instance.k3s_control_plane]

  provisioner "local-exec" {
    command = <<-EOT
      INSTANCE_ID="${aws_instance.k3s_control_plane.id}"
      STATUS=$(aws ec2 describe-instance-status --instance-ids $INSTANCE_ID --query "InstanceStatuses[0].InstanceStatus.Status" --output text)

      while [ "$STATUS" != "ok" ]; do
        echo "Waiting for instance health check to pass..."
        sleep 10
        STATUS=$(aws ec2 describe-instance-status --instance-ids $INSTANCE_ID --query "InstanceStatuses[0].InstanceStatus.Status" --output text)
      done
      echo "Instance health check passed!"
    EOT
  }
}

resource "null_resource" "provision_k3s_control_plane" {
  depends_on = [null_resource.wait_for_health_check_k3s_control_plane]

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
      "export AWS_DEFAULT_REGION='${var.aws_region}'",
      "aws ssm get-parameter --name '${var.key_param_path}' --with-decryption --query \"Parameter.Value\" --output text > ${local_file.ssh_key.filename}",
      "sudo chmod 600 ${local_file.ssh_key.filename}",
      "curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC='--write-kubeconfig-mode 644 --tls-san k8s.elysium-space.com --tls-san ${aws_instance.bastion.public_ip} --tls-san ${aws_instance.k3s_control_plane.private_ip} --kube-apiserver-arg bind-address=0.0.0.0' sh -",
      "curl -s http://169.254.169.254/latest/meta-data/local-ipv4 | sudo tee /var/lib/rancher/k3s/server/ip",
      "sudo sed -i \"s|https://127.0.0.1:6443|https://${aws_instance.k3s_control_plane.private_ip}:6443|\" /etc/rancher/k3s/k3s.yaml",
      "aws ssm put-parameter --name '${var.kubeconfig_param_path}' --value file:///etc/rancher/k3s/k3s.yaml --type SecureString --overwrite",
    ]
  }
}

resource "aws_instance" "k3s_worker" {
  depends_on = [
    local_file.ssh_key,
    null_resource.provision_k3s_control_plane,
    aws_nat_gateway.natgw
  ]
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type_worker
  subnet_id                   = aws_subnet.private[1].id
  vpc_security_group_ids      = [aws_security_group.vm_private_sg.id]
  key_name                    = var.key_pair
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.worker_profile.name
  user_data_replace_on_change = true

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

  user_data = templatefile("${path.module}/templates/worker.sh", {
    PROJECT_NAME     = var.project_name
    ENVIRONMENT_NAME = var.environment_name
    CERT_PATH        = var.cert_path
    KEY_PARAM_PATH   = var.key_param_path
    JENKINS_DATA_DIR = var.jenkins_data_dir
  })

  tags = {
    Name     = "${var.project_name}-k3s-worker-${var.environment_name}",
    K8s_Role = "worker"
  }
}

resource "null_resource" "wait_for_health_check_k3s_worker" {
  depends_on = [aws_instance.k3s_worker]

  provisioner "local-exec" {
    command = <<-EOT
      INSTANCE_ID="${aws_instance.k3s_worker.id}"
      STATUS=$(aws ec2 describe-instance-status --instance-ids $INSTANCE_ID --query "InstanceStatuses[0].InstanceStatus.Status" --output text)

      while [ "$STATUS" != "ok" ]; do
        echo "Waiting for instance health check to pass..."
        sleep 10
        STATUS=$(aws ec2 describe-instance-status --instance-ids $INSTANCE_ID --query "InstanceStatuses[0].InstanceStatus.Status" --output text)
      done
      echo "Instance health check passed!"
    EOT
  }
}

resource "null_resource" "provision_k3s_worker" {
  depends_on = [null_resource.wait_for_health_check_k3s_worker]

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
      "export AWS_DEFAULT_REGION='${var.aws_region}'",
      "aws ssm get-parameter --name '${var.key_param_path}' --with-decryption --query \"Parameter.Value\" --output text > ${local_file.ssh_key.filename}",
      "sudo chmod 600 ${local_file.ssh_key.filename}",
      "export K3S_TOKEN=$(ssh -o StrictHostKeyChecking=no -i ${local_file.ssh_key.filename} ubuntu@${aws_instance.k3s_control_plane.private_ip} 'sudo cat /var/lib/rancher/k3s/server/node-token')",
      "export K3S_URL=https://${aws_instance.k3s_control_plane.private_ip}:6443",
      "curl -sfL https://get.k3s.io | sh -"
    ]
  }
}

data "template_file" "nginx_k3s_conf" {
  depends_on = [null_resource.provision_k3s_worker]
  template   = file("./templates/nginx_k3s.tpl")
  vars = {
    k3s_control_plane_private_ip = aws_instance.k3s_control_plane.private_ip
  }
}

resource "aws_ssm_parameter" "nginx_k3s_conf" {
  depends_on = [data.template_file.nginx_k3s_conf]
  name       = "/conf/nginx_k3s_conf"
  type       = "String"
  value      = data.template_file.nginx_k3s_conf.rendered
}

data "template_file" "nginx_jenkins_conf" {
  depends_on = [null_resource.provision_k3s_worker]
  template   = file("./templates/nginx_jenkins.tpl")
  vars = {
    k3s_control_plane_private_ip = aws_instance.k3s_control_plane.private_ip
  }
}

resource "aws_ssm_parameter" "nginx_jenkins_conf" {
  depends_on = [data.template_file.nginx_jenkins_conf]
  name       = "/conf/nginx_jenkins_conf"
  type       = "String"
  value      = data.template_file.nginx_jenkins_conf.rendered
}

resource "null_resource" "apply_nginx_config" {
  depends_on = [
    null_resource.provision_k3s_worker,
    aws_ssm_parameter.nginx_k3s_conf,
    aws_ssm_parameter.nginx_jenkins_conf
  ]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = aws_instance.bastion.public_ip
      user        = "ubuntu"
      private_key = file(local_file.ssh_key.filename)
    }

    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y awscli",
      "export AWS_DEFAULT_REGION='${var.aws_region}'",
      "for param in nginx_k3s_conf nginx_jenkins_conf; do",
      "  for i in {1..5}; do",
      "    VALUE=$(aws ssm get-parameter --name \"/conf/$param\" --query \"Parameter.Value\" --output text 2>/dev/null)",
      "    if [ -n \"$VALUE\" ]; then",
      "      if [ \"$param\" = 'nginx_k3s_conf' ]; then",
      "        echo \"$VALUE\" | sudo tee /etc/nginx/modules-enabled/k3s.conf > /dev/null",
      "      else",
      "        echo \"$VALUE\" | sudo tee /etc/nginx/sites-enabled/jenkins.conf > /dev/null",
      "      fi",
      "      break",
      "    fi",
      "    sleep 5",
      "  done",
      "done",
      "sudo nginx -t && sudo systemctl restart nginx"
    ]
  }
}

# resource "aws_ssm_document" "apply_nginx_conf" {
#   depends_on    = [null_resource.wait_for_health_check_bastion, null_resource.provision_bastion, aws_ssm_parameter.nginx_k3s_conf, aws_ssm_parameter.nginx_jenkins_conf]
#   name          = "apply_nginx_conf_ssm"
#   document_type = "Command"
#   content = jsonencode({
#     schemaVersion = "2.2",
#     description   = "Apply nginx reverse proxy k3s config, copy extra files, restart service, and run post-restart command",
#     mainSteps = [
#       {
#         action = "aws:runShellScript",
#         name   = "applyConfigAndCopyFiles",
#         inputs = {
#           runCommand = [
#             "for param in nginx_k3s_conf nginx_jenkins_conf; do",
#             "  for i in {1..5}; do",
#             "    VALUE=$(aws ssm get-parameter --name \"/conf/$param\" --query \"Parameter.Value\" --output text 2>/dev/null)",
#             "    if [ -n \"$VALUE\" ] && [[ \"$VALUE\" != *'ParameterNotFound'* ]]; then",
#             "      if [ \"$param\" = 'nginx_k3s_conf' ]; then",
#             "        echo \"$VALUE\" > /etc/nginx/modules-enabled/k3s.conf",
#             "      else",
#             "        echo \"$VALUE\" > /etc/nginx/conf.d/jenkins.conf",
#             "      fi",
#             "      break",
#             "    fi",
#             "    echo \"Retrying $param...\"; sleep 5",
#             "  done",
#             "done",
#             "sudo nginx -t || { echo 'NGINX config test failed'; exit 1; }",
#             "sudo systemctl restart nginx && sudo systemctl enable nginx"
#           ]
#         }
#       }
#     ]
#   })
# }

# resource "aws_ssm_association" "apply_nginx_conf_association" {
#   name = aws_ssm_document.apply_nginx_conf.name
#   targets {
#     key    = "InstanceIds"
#     values = [aws_instance.bastion.id]
#   }
# }
