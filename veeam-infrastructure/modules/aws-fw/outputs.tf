# outputs.tf for network_firewall module

output "firewall_arn" {
  description = "The ARN of the Network Firewall."
  value       = aws_networkfirewall_firewall.main.arn
}

output "firewall_policy_arn" {
  description = "The ARN of the Network Firewall Policy."
  value       = aws_networkfirewall_firewall_policy.main.arn
}