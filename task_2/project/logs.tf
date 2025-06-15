resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flow-logs"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.cloudwatch.arn

  tags = merge(
    var.tags,
    {
      Name = "VPCFlowLogGroup"
    }
  )
}

resource "aws_flow_log" "vpc_flow" {
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  log_destination_type = "cloud-watch-logs"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.main.id
  iam_role_arn         = aws_iam_role.vpc_flow_logs_role.arn

  tags = merge(
    var.tags,
    {
      Name = "VPCFlowLogs"
    }
  )
}
