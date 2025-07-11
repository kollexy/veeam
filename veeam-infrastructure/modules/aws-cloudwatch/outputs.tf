# outputs.tf for cloudwatch_monitoring module

output "alerts_sns_topic_arn" {
  description = "The ARN of the SNS topic for alerts."
  value       = aws_sns_topic.alerts.arn
}

output "nfw_flow_log_group_name" {
  description = "Name of the CloudWatch Log Group for Network Firewall flow logs."
  value       = aws_cloudwatch_log_group.nfw_flow_logs.name
}

output "nfw_alert_log_group_name" {
  description = "Name of the CloudWatch Log Group for Network Firewall alert logs."
  value       = aws_cloudwatch_log_group.nfw_alert_logs.name
}