# AVD-AWS-0178 (MEDIUM)
# See https://avd.aquasec.com/misconfig/aws-autoscaling-enable-at-rest-encryption
resource "aws_iam_role" "vpc_flow_logs_role" {
  name = "VPCFlowLogsRole"

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
    Name = "VPCFlowLogsRole"
  }
}

resource "aws_iam_role_policy_attachment" "vpc_flow_logs_policy" {
  role       = aws_iam_role.vpc_flow_logs_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}
