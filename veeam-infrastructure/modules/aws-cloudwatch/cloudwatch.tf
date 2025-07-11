# main.tf for cloudwatch_monitoring module

# CloudWatch Log Group for Network Firewall Flow Logs
resource "aws_cloudwatch_log_group" "nfw_flow_logs" {
  name              = "/aws/network-firewall/${var.project_name}-${var.environment}/flow-logs"
  retention_in_days = 731 # 2 years retention for logs

  tags = {
    Name        = "${var.project_name}-${var.environment}-nfw-flow-logs"
    Environment = var.environment
    Project     = var.project_name
  }
}

# CloudWatch Log Group for Network Firewall Alert Logs
resource "aws_cloudwatch_log_group" "nfw_alert_logs" {
  name              = "/aws/network-firewall/${var.project_name}-${var.environment}/alert-logs"
  retention_in_days = 731 # 2 years retention for logs

  tags = {
    Name        = "${var.project_name}-${var.environment}-nfw-alert-logs"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Configure Network Firewall to send logs to CloudWatch (assuming this is managed by NFW module)
# This part is typically done in the `network_firewall` module as it's a direct property of the firewall.
# However, you can ensure log group existence here and then refer to their ARNs in the NFW module.
# For simplicity, if the NFW module takes log group name/ARN as input, you'd output them from here.
# Assuming `aws_networkfirewall_logging_configuration` is handled in `network_firewall` module,
# this module primarily creates the log groups and then the alarms on them.

# SNS Topic for alerts
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-${var.environment}-backup-alerts"

  tags = {
    Name        = "${var.project_name}-${var.environment}-backup-alerts"
    Environment = var.environment
    Project     = var.project_name
  }
}

# SNS Topic Subscriptions (e.g., email)
resource "aws_sns_topic_subscription" "email_subscriptions" {
  for_each  = toset(var.sns_topic_email_recipients)
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

# CloudWatch Alarm: High S3 4xx Errors (Client Errors)
resource "aws_cloudwatch_metric_alarm" "s3_4xx_errors" {
  alarm_name          = "${var.project_name}-${var.environment}-s3-4xx-errors-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "4xxErrors"
  namespace           = "AWS/S3"
  period              = 300 # 5 minutes
  statistic           = "Sum"
  threshold           = 10 # More than 10 4xx errors in 5 minutes
  alarm_description   = "Alarm when S3 4xx errors exceed threshold"
  actions_enabled     = true
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    BucketName = var.s3_bucket_name
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-s3-4xx-errors-alarm"
    Environment = var.environment
    Project     = var.project_name
  }
}

# CloudWatch Alarm: Unusual S3 Delete Requests (potential ransomware/malicious activity)
resource "aws_cloudwatch_metric_alarm" "s3_delete_requests" {
  alarm_name          = "${var.project_name}-${var.environment}-s3-delete-requests-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "DeleteRequests"
  namespace           = "AWS/S3"
  period              = 300 # 5 minutes
  statistic           = "Sum"
  threshold           = 5 # More than 5 delete requests in 5 minutes (adjust based on normal operations)
  alarm_description   = "Alarm when S3 delete requests exceed threshold (potential malicious activity)."
  actions_enabled     = true
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    BucketName = var.s3_bucket_name
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-s3-delete-requests-alarm"
    Environment = var.environment
    Project     = var.project_name
  }
}

# CloudWatch Alarm: Network Firewall Denied Flow Logs (example)
# Requires Network Firewall to send FLOW logs to CloudWatch Logs
resource "aws_cloudwatch_log_metric_filter" "nfw_denied_flows_filter" {
  name           = "${var.project_name}-${var.environment}-nfw-denied-flows-filter"
  pattern        = "[action=DENY]" # Filter for "DENY" actions in the logs
  log_group_name = aws_cloudwatch_log_group.nfw_flow_logs.name

  metric_transformation {
    name          = "DeniedFlows"
    namespace     = "NetworkFirewallCustomMetrics"
    value         = "1"
    default_value = 0
  }
}

resource "aws_cloudwatch_metric_alarm" "nfw_denied_flows_alarm" {
  alarm_name          = "${var.project_name}-${var.environment}-nfw-denied-flows-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "DeniedFlows"
  namespace           = "NetworkFirewallCustomMetrics"
  period              = 300 # 5 minutes
  statistic           = "Sum"
  threshold           = 0 # Alert on any denied flows
  alarm_description   = "Alarm when Network Firewall denies traffic."
  actions_enabled     = true
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  tags = {
    Name        = "${var.project_name}-${var.environment}-nfw-denied-flows-alarm"
    Environment = var.environment
    Project     = var.project_name
  }
}