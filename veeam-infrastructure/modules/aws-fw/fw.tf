# main.tf for network_firewall module

resource "aws_networkfirewall_firewall_policy" "main" {
  name = "${var.project_name}-${var.environment}-firewall-policy"

  firewall_policy {
    stateless_default_actions = ["aws:pass"] # Default for packets not matched by stateless rules
    stateless_fragment_default_actions = ["aws:pass"]
    # stateful_default_actions = ["aws:alert_strict"] # Action for stateful engine to take on unmatched packets

    # Associate rule groups (defined below or passed as variables)
    dynamic "stateful_rule_group_reference" {
      for_each = var.firewall_rules_config.stateful_rule_group_arns
      content {
        resource_arn = stateful_rule_group_reference.value
      }
    }
    dynamic "stateless_rule_group_reference" {
      for_each = var.firewall_rules_config.stateless_rule_group_arns
      content {
        resource_arn = stateless_rule_group_reference.value
      }
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-firewall-policy"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Example Stateful Rule Group (Customize as needed)
# This rule group would contain rules to allow/deny specific traffic patterns.
# For Veeam, you might allow specific outbound traffic from any AWS EC2 mount servers
# if they interact with Azure or other internet resources.
resource "aws_networkfirewall_rule_group" "outbound_allow" {
  count = length(var.firewall_rules_config.stateful_rules) > 0 ? 1 : 0 # Only create if rules are provided
  name  = "${var.project_name}-${var.environment}-outbound-allow-rules"
  type  = "STATEFUL"
  capacity = 100 # Adjust capacity based on the number and complexity of rules

  rule_group {
    stateful_rules {
      dynamic "rule_definition" {
        for_each = var.firewall_rules_config.stateful_rules
        content {
          actions {
            type = rule_definition.value.action
          }
          match_attributes {
            protocols = [rule_definition.value.protocol]
            source_ports {
              from_port = rule_definition.value.source_port_from
              to_port   = rule_definition.value.source_port_to
            }
            destination_ports {
              from_port = rule_definition.value.dest_port_from
              to_port   = rule_definition.value.dest_port_to
            }
            sources {
              address_definition = rule_definition.value.source_ip
            }
            destinations {
              address_definition = rule_definition.value.dest_ip
            }
          }
        }
      }
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-outbound-allow-rg"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_networkfirewall_firewall" "main" {
  name                = "${var.project_name}-${var.environment}-firewall"
  vpc_id              = var.vpc_id
  firewall_policy_arn = aws_networkfirewall_firewall_policy.main.arn

  dynamic "subnet_mapping" {
    for_each = var.firewall_subnet_ids
    content {
      subnet_id = subnet_mapping.value
    }
  }

  delete_protection              = true
  firewall_policy_change_protection = true
  subnet_change_protection       = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-firewall"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Configure logging for Network Firewall
resource "aws_networkfirewall_logging_configuration" "main" {
  firewall_arn = aws_networkfirewall_firewall.main.arn

  logging_configuration {
    dynamic "log_destination_config" {
      for_each = var.logging_configuration != null ? [var.logging_configuration] : []
      content {
        log_type = log_destination_config.value.log_type
        log_destination_type = log_destination_config.value.log_destination_type
        log_destination    = {
          logGroupName = log_destination_config.value.log_destination_type == "CloudWatchLogs" ? var.network_firewall_log_group_name : null
          bucketName   = log_destination_config.value.log_destination_type == "S3" ? var.network_firewall_log_bucket_name : null
        }
      }
    }
  }
}

# Update route tables to send traffic through Network Firewall
# This assumes a "centralized inspection" model for outbound/ingress via IGW
# For private subnets: default route to Network Firewall endpoints
resource "aws_route" "private_to_firewall" {
  for_each               = { for i, subnet_id in var.firewall_subnet_ids : subnet_id => i }
  route_table_id         = var.private_route_table_id # From VPC module
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = aws_networkfirewall_firewall.main.firewall_status[0].sync_states[each.value].attachment[0].endpoint_id
}

# IMPORTANT: For traffic originating from the internet (e.g., from Azure Veeam if it was hitting an EC2 instance in AWS)
# you would adjust the public route table to route traffic THROUGH the firewall.
# However, as Veeam directly hits S3 public endpoint, this specific flow isn't managed by the firewall in the VPC.
# The firewall is protecting traffic that enters/exits the VPC via the IGW, or internal VPC traffic.