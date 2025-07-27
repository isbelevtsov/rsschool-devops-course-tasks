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

resource "aws_iam_policy" "bastion_policy" {
  name        = "${var.project_name}-bastion-policy-${var.environment_name}"
  description = "Allow Bastion EC2 instance to read SSH key from SSM"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "ssm:GetParameter",
        Resource = [
          "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:parameter/${var.project_name}/${var.environment_name}/common/*",
          "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:parameter/${var.project_name}/${var.environment_name}/${local.bastion_role}/*",
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "kms:Decrypt",
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "ec2messages:*",
          "cloudwatch:PutMetricData",
          "sts:GetCallerIdentity",
          "ssm:SendCommand",
          "ssm:GetCommandInvocation",
          "ssm:AmazonSSMManagedInstanceCore",
          "ssm:UpdateInstanceInformation",
          "ssm:DescribeInstanceProperties",
          "ssm:ListAssociations",
          "ssm:ListInstanceAssociations",
          "ssm:ListCommandInvocations",
          "ssm:ListCommands",
          "ssm:ListCommandInvocations",
          "ssmmessages:*"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "bastion_policy_attach" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = aws_iam_policy.bastion_policy.arn
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

resource "aws_iam_policy" "controlplane_policy" {
  name        = "${var.project_name}-controlplane-policy-${var.environment_name}"
  description = "Allow EC2 to read kubeconfig from SSM"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "ssm:PutParameter",
        Resource = [
          "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:parameter/${var.project_name}/${var.environment_name}/kube/*"
        ]

      },
      {
        Effect = "Allow",
        Action = "ssm:GetParameter",
        Resource = [
          "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:parameter/${var.project_name}/${var.environment_name}/common/*",
          "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:parameter/${var.project_name}/${var.environment_name}/kube/*",
          "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:parameter/${var.project_name}/${var.environment_name}/${local.control_plane_role}/*"
        ]

      },
      {
        Effect = "Allow",
        Action = [
          "kms:Decrypt",
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "ec2:DescribeRegions",
          "ec2messages:*",
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:CreateRepository",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "cloudwatch:PutMetricData",
          "sts:AssumeRole",
          "sts:GetCallerIdentity",
          "ssm:SendCommand",
          "ssm:GetCommandInvocation",
          "ssm:AmazonSSMManagedInstanceCore",
          "ssm:UpdateInstanceInformation",
          "ssm:DescribeInstanceProperties",
          "ssm:ListAssociations",
          "ssm:ListInstanceAssociations",
          "ssm:ListCommandInvocations",
          "ssm:ListCommands",
          "ssm:ListCommandInvocations",
          "ssmmessages:*"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "controlplane_policy_attach" {
  role       = aws_iam_role.controlplane_role.name
  policy_arn = aws_iam_policy.controlplane_policy.arn
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

resource "aws_iam_policy" "worker_policy" {
  name        = "${var.project_name}-worker-policy-${var.environment_name}"
  description = "Allow EC2 to read kubeconfig from SSM"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "ssm:GetParameter",
        Resource = [
          "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:parameter/${var.project_name}/${var.environment_name}/common/*",
          "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:parameter/${var.project_name}/${var.environment_name}/kube/*",
          "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:parameter/${var.project_name}/${var.environment_name}/${local.worker_role}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "kms:Decrypt",
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "ec2:DescribeRegions",
          "ec2messages:*",
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:CreateRepository",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "cloudwatch:PutMetricData",
          "sts:AssumeRole",
          "sts:GetCallerIdentity",
          "ssm:SendCommand",
          "ssm:GetCommandInvocation",
          "ssm:AmazonSSMManagedInstanceCore",
          "ssm:UpdateInstanceInformation",
          "ssm:DescribeInstanceProperties",
          "ssm:ListAssociations",
          "ssm:ListInstanceAssociations",
          "ssm:ListCommandInvocations",
          "ssm:ListCommands",
          "ssm:ListCommandInvocations",
          "ssmmessages:*"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "worker_policy_attach" {
  role       = aws_iam_role.worker_role.name
  policy_arn = aws_iam_policy.worker_policy.arn
}

resource "aws_iam_instance_profile" "worker_profile" {
  name = "${var.project_name}-worker-instance-profile-${var.environment_name}"
  role = aws_iam_role.worker_role.name
}

resource "aws_iam_role" "k3s_jenkins_ecr_role" {
  name = "${var.project_name}-k3s-jenkins-ecr-role-${var.environment_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      },
      {
        Sid    = "JenkinsAssumeRole",
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${var.aws_account_id}:role/${var.project_name}-controlplane-role-${var.environment_name}",
            "arn:aws:iam::${var.aws_account_id}:role/${var.project_name}-worker-role-${var.environment_name}"
          ]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_access" {
  role       = aws_iam_role.k3s_jenkins_ecr_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}

resource "aws_iam_role_policy" "controlplane_assume_kube2iam_role" {
  name = "assume-kube2iam-jenkins-ecr-role-controlplane"
  role = aws_iam_role.controlplane_role.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "sts:AssumeRole",
        Resource = aws_iam_role.k3s_jenkins_ecr_role.arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "worker_assume_kube2iam_role" {
  name = "assume-kube2iam-jenkins-ecr-role-worker"
  role = aws_iam_role.worker_role.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "sts:AssumeRole",
        Resource = aws_iam_role.k3s_jenkins_ecr_role.arn
      }
    ]
  })
}

resource "aws_iam_role" "k3s_monitoring_ses_role" {
  name = "${var.project_name}-k3s-monitoring-ses-role-${var.environment_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "EC2AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      },
      {
        Sid    = "Kube2IAMAssumeRole",
        Effect = "Allow",
        Principal = {
          AWS = [
            "arn:aws:iam::${var.aws_account_id}:role/${var.project_name}-controlplane-role-${var.environment_name}",
            "arn:aws:iam::${var.aws_account_id}:role/${var.project_name}-worker-role-${var.environment_name}"
          ]
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "k3s_monitoring_ses_policy" {
  name        = "${var.project_name}-k3s-monitoring-ses-policy-${var.environment_name}"
  description = "Allow Grafana/Alertmanager to send emails via SES"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "monitoring_ses_attach" {
  role       = aws_iam_role.k3s_monitoring_ses_role.name
  policy_arn = aws_iam_policy.k3s_monitoring_ses_policy.arn
}

resource "aws_iam_role_policy" "controlplane_assume_kube2iam_ses_role" {
  name = "assume-kube2iam-ses-role-controlplane"
  role = aws_iam_role.controlplane_role.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "sts:AssumeRole",
        Resource = aws_iam_role.k3s_monitoring_ses_role.arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "worker_assume_kube2iam_ses_role" {
  name = "assume-kube2iam-ses-role-worker"
  role = aws_iam_role.worker_role.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "sts:AssumeRole",
        Resource = aws_iam_role.k3s_monitoring_ses_role.arn
      }
    ]
  })
}

resource "aws_iam_user" "grafana_smtp_user" {
  name = "${var.project_name}-grafana-smtp-${var.environment_name}"
}

resource "aws_iam_user_policy" "grafana_smtp_ses_policy" {
  name = "${var.project_name}-GrafanaSESSendEmail-${var.environment_name}"
  user = aws_iam_user.grafana_smtp_user.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_access_key" "grafana_smtp_user_key" {
  user = aws_iam_user.grafana_smtp_user.name
}
