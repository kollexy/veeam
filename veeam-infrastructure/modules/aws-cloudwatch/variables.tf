# variables.tf for cloudwatch_monitoring module

variable "project_name" {
  description = "Name of the project."
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, prod)."
  type        = string
}

variable "s3_bucket_name" {
  description = "The name of the S3 bucket to monitor."
  type        = string
}

variable "network_firewall_arn" {
  description = "The ARN of the Network Firewall instance to monitor."
  type        = string
}

variable "sns_topic_email_recipients" {
  description = "A list of email addresses to receive SNS notifications."
  type        = list(string)
}