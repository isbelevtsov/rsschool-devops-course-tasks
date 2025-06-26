# AVD-AWS-0178 (MEDIUM)
# See https://avd.aquasec.com/misconfig/aws-autoscaling-enable-at-rest-encryption
resource "aws_iam_role" "vpc_flow_logs_role" {
  name = "${var.project_name}-vpc-flow-logs-role-${var.environment_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      },
      Effect = "Allow",
      Sid    = ""
    }]
  })

  tags = {
    Name = "${var.project_name}-vpc-flow-logs-role-${var.environment_name}"
  }
}

resource "aws_iam_role_policy_attachment" "vpc_flow_logs_policy" {
  role       = aws_iam_role.vpc_flow_logs_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_iam_role" "bastion_role" {
  name = "${var.project_name}-bastion-role-${var.environment_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "ssm_bastion_policy" {
  name        = "${var.project_name}-ssm-bastion-policy-${var.environment_name}"
  description = "Allow Bastion EC2 instance to read SSH key from SSM"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "ssm:GetParameter",
        Resource = "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:parameter${var.key_param_path}"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_bastion_policy_attach" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = aws_iam_policy.ssm_bastion_policy.arn
}

resource "aws_iam_instance_profile" "bastion_profile" {
  name = "${var.project_name}-bastion-instance-profile-${var.environment_name}"
  role = aws_iam_role.bastion_role.name
}

resource "aws_iam_role" "controlplane_role" {
  name = "${var.project_name}-controlplane-role-${var.environment_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "ssm_controlplane_write_policy" {
  name        = "${var.project_name}-ssm-controlplane-policy-${var.environment_name}"
  description = "Allow EC2 to read kubeconfig from SSM"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "ssm:PutParameter",
        Resource = "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:parameter${var.kubeconfig_param_path}"
      }
    ]
  })
}

resource "aws_iam_policy" "ssm_controlplane_read_policy" {
  name        = "${var.project_name}-ssm-controlplane-policy-${var.environment_name}"
  description = "Allow EC2 to read kubeconfig from SSM"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "ssm:GettParameter",
        Resource = "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:parameter${var.key_param_path}"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_controlplane_write_policy_attach" {
  role       = aws_iam_role.controlplane_role.name
  policy_arn = aws_iam_policy.ssm_controlplane_write_policy.arn
}

resource "aws_iam_role_policy_attachment" "ssm_controlplane_read_policy_attach" {
  role       = aws_iam_role.controlplane_role.name
  policy_arn = aws_iam_policy.ssm_controlplane_read_policy.arn
}

resource "aws_iam_instance_profile" "controlplane_profile" {
  name = "${var.project_name}-controlplane-instance-profile-${var.environment_name}"
  role = aws_iam_role.controlplane_role.name
}

resource "aws_iam_role" "worker_role" {
  name = "${var.project_name}-worker-role-${var.environment_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "ssm_worker_policy" {
  name        = "${var.project_name}-ssm-worker-policy-${var.environment_name}"
  description = "Allow EC2 to read kubeconfig from SSM"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "ssm:GetParameter",
        Resource = [
          "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:parameter${var.kubeconfig_param_path}",
          "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:parameter${var.key_param_path}"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_worker_policy_attach" {
  role       = aws_iam_role.worker_role.name
  policy_arn = aws_iam_policy.ssm_worker_policy.arn
}

resource "aws_iam_instance_profile" "worker_profile" {
  name = "${var.project_name}-worker-instance-profile-${var.environment_name}"
  role = aws_iam_role.worker_role.name
}
