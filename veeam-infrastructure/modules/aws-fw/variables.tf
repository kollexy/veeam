# variables.tf for network_firewall module

variable "project_name" {
  description = "Name of the project."
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, prod)."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC where Network Firewall will be deployed."
  type        = string
}

variable "firewall_subnet_ids" {
  description = "List of subnet IDs where Network Firewall endpoints will be created."
  type        = list(string)
}

variable "private_route_table_id" {
  description = "The ID of the private route table to update for firewall routing."
  type        = string
}

variable "firewall_rules_config" {
  description = "Configuration for Network Firewall rule groups and policy."
  type = object({
    stateful_rule_group_arns = list(string)
    stateless_rule_group_arns = list(string)
    stateful_rules = list(object({
      action = string # e.g., "PASS", "DROP", "ALERT"
      protocol = string # e.g., "TCP", "UDP", "IP"
      source_ip = string # CIDR
      dest_ip = string # CIDR
      source_port_from = number
      source_port_to = number
      dest_port_from = number
      dest_port_to = number
    }))
    # You can add more complex structures for stateless rules, Suricata rules, etc.
  })
  default = {
    stateful_rule_group_arns  = []
    stateless_rule_group_arns = []
    stateful_rules            = []
  }
}

variable "logging_configuration" {
  description = "Configuration for Network Firewall logging."
  type = object({
    log_type = string # "FLOW" or "ALERT"
    log_destination_type = string # "CloudWatchLogs" or "S3"
    # Additional fields might be needed depending on log_destination_type
  })
  default = null # No logging by default
}

variable "network_firewall_log_group_name" {
  description = "Name of the CloudWatch Log Group for Network Firewall logs."
  type        = string
  default     = null # Only required if log_destination_type is CloudWatchLogs
}

variable "network_firewall_log_bucket_name" {
  description = "Name of the S3 bucket for Network Firewall logs."
  type        = string
  default     = null # Only required if log_destination_type is S3
}