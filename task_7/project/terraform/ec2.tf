locals {
  bastion_role       = "bastion"
  control_plane_role = "k3s-control-plane"
  worker_role        = "k3s-worker"
  nginx_configs = {
    nginx_k3s = {
      template    = "./templates/nginx_k3s.tpl"
      output_file = "/etc/nginx/modules-enabled/k3s.conf"
    }
    nginx_jenkins = {
      template    = "./templates/nginx_jenkins.tpl"
      output_file = "/etc/nginx/sites-enabled/jenkins.conf"
    }
    nginx_flask = {
      template    = "./templates/nginx_flask.tpl"
      output_file = "/etc/nginx/sites-enabled/flask.conf"
    }
    nginx_grafana = {
      template    = "./templates/nginx_grafana.tpl"
      output_file = "/etc/nginx/sites-enabled/grafana.conf"
    }
    nginx_prometheus = {
      template    = "./templates/nginx_prometheus.tpl"
      output_file = "/etc/nginx/sites-enabled/prometheus.conf"
    }
    nginx_alertmanager = {
      template    = "./templates/nginx_alertmanager.tpl"
      output_file = "/etc/nginx/sites-enabled/alertmanager.conf"
    }
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu*22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_ssm_parameter" "ssh_private_key" {
  name        = "/${var.project_name}/${var.environment_name}/common/ssh_key"
  description = "Private SSH key for accessing EC2 instances"
  type        = "SecureString"
  value       = tls_private_key.ssh.private_key_pem
  overwrite   = true
}

resource "aws_ssm_parameter" "ssh_public_key" {
  name        = "/${var.project_name}/${var.environment_name}/common/ssh_key_public"
  description = "Public SSH key for EC2 key pair"
  type        = "String"
  value       = tls_private_key.ssh.public_key_openssh
  overwrite   = true
}

resource "aws_key_pair" "generated" {
  key_name   = "${var.project_name}-ssh-key-${var.environment_name}"
  public_key = tls_private_key.ssh.public_key_openssh
}

resource "aws_ssm_parameter" "route53_domain" {
  name        = "/${var.project_name}/${var.environment_name}/common/route53_domain"
  description = "Route53 domain name"
  type        = "String"
  value       = var.route53_domain
  overwrite   = true
}

resource "aws_ssm_parameter" "jenkins_data_dir" {
  name        = "/${var.project_name}/${var.environment_name}/kube/jenkins_data_dir"
  description = "Jenkins persistent data directory"
  type        = "String"
  value       = var.jenkins_data_dir
  overwrite   = true
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type_bastion
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  key_name                    = aws_key_pair.generated.key_name
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.bastion_profile.name
  user_data_replace_on_change = true
  source_dest_check           = false

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

  user_data = file("${path.module}/templates/${local.bastion_role}.sh")

  tags = {
    Name = "${var.project_name}-${local.bastion_role}-${var.environment_name}",
    Role = local.bastion_role
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

resource "aws_instance" "k3s_control_plane" {
  depends_on                  = [null_resource.wait_for_health_check_bastion]
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type_cp
  subnet_id                   = aws_subnet.private[0].id
  vpc_security_group_ids      = [aws_security_group.vm_private_sg.id]
  key_name                    = aws_key_pair.generated.key_name
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

  user_data = file("${path.module}/templates/${local.control_plane_role}.sh")

  tags = {
    Name = "${var.project_name}-${local.control_plane_role}-${var.environment_name}",
    Role = local.control_plane_role
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

resource "aws_instance" "k3s_worker" {
  depends_on                  = [null_resource.wait_for_health_check_k3s_control_plane]
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type_worker
  subnet_id                   = aws_subnet.private[1].id
  vpc_security_group_ids      = [aws_security_group.vm_private_sg.id]
  key_name                    = aws_key_pair.generated.key_name
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

  user_data = file("${path.module}/templates/${local.worker_role}.sh")

  tags = {
    Name = "${var.project_name}-${local.worker_role}-${var.environment_name}",
    Role = local.worker_role
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

data "template_file" "nginx_confs" {
  for_each   = local.nginx_configs
  depends_on = [null_resource.wait_for_health_check_k3s_control_plane]
  template   = file(each.value.template)
  vars = {
    k3s_control_plane_private_ip = aws_instance.k3s_control_plane.private_ip
    route53_domain               = var.route53_domain
  }
}

resource "aws_ssm_parameter" "nginx_confs" {
  for_each   = data.template_file.nginx_confs
  depends_on = [data.template_file.nginx_confs]
  name       = "/${var.project_name}/${var.environment_name}/${local.bastion_role}/${each.key}"
  type       = "String"
  value      = each.value.rendered
}

resource "aws_ssm_document" "apply_nginx_conf" {
  depends_on = [
    null_resource.wait_for_health_check_bastion,
    aws_ssm_parameter.nginx_confs
  ]

  name          = "apply_nginx_conf_ssm"
  document_type = "Command"

  content = jsonencode({
    schemaVersion = "2.2",
    description   = "Apply nginx reverse proxy k3s config, copy extra files, restart service, and run post-restart command",
    mainSteps = [
      {
        action = "aws:runShellScript",
        name   = "applyConfigAndCopyFiles",
        inputs = {
          runCommand = [
            "VALUES=$(aws ssm get-parameter --name \"/${var.project_name}/${var.environment_name}/${local.bastion_role}/nginx_k3s\" --query \"Parameter.Value\" --output text --region ${var.aws_region})",
            "echo \"$VALUES\" | sudo tee ${local.nginx_configs.nginx_k3s.output_file} > /dev/null",
            "VALUES=$(aws ssm get-parameter --name \"/${var.project_name}/${var.environment_name}/${local.bastion_role}/nginx_jenkins\" --query \"Parameter.Value\" --output text --region ${var.aws_region})",
            "echo \"$VALUES\" | sudo tee ${local.nginx_configs.nginx_jenkins.output_file} > /dev/null",
            "VALUES=$(aws ssm get-parameter --name \"/${var.project_name}/${var.environment_name}/${local.bastion_role}/nginx_flask\" --query \"Parameter.Value\" --output text --region ${var.aws_region})",
            "echo \"$VALUES\" | sudo tee ${local.nginx_configs.nginx_flask.output_file} > /dev/null",
            "VALUES=$(aws ssm get-parameter --name \"/${var.project_name}/${var.environment_name}/${local.bastion_role}/nginx_grafana\" --query \"Parameter.Value\" --output text --region ${var.aws_region})",
            "echo \"$VALUES\" | sudo tee ${local.nginx_configs.nginx_grafana.output_file} > /dev/null",
            "VALUES=$(aws ssm get-parameter --name \"/${var.project_name}/${var.environment_name}/${local.bastion_role}/nginx_prometheus\" --query \"Parameter.Value\" --output text --region ${var.aws_region})",
            "echo \"$VALUES\" | sudo tee ${local.nginx_configs.nginx_prometheus.output_file} > /dev/null",
            "VALUES=$(aws ssm get-parameter --name \"/${var.project_name}/${var.environment_name}/${local.bastion_role}/nginx_alertmanager\" --query \"Parameter.Value\" --output text --region ${var.aws_region})",
            "echo \"$VALUES\" | sudo tee ${local.nginx_configs.nginx_alertmanager.output_file} > /dev/null",
            "sudo nginx -t",
            "sudo systemctl restart nginx"
          ]
        }
      }
    ]
  })
}

resource "aws_ssm_association" "apply_nginx_conf_association" {
  name = aws_ssm_document.apply_nginx_conf.name
  targets {
    key    = "InstanceIds"
    values = [aws_instance.bastion.id]
  }
}
