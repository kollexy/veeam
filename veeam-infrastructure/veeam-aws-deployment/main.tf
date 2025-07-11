# versions.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region
}

# main.tf (in root)
module "vpc" {
  source                = "./modules/vpc"
  vpc_cidr_block        = var.aws_vpc_cidr_block # 172.16.0.0/16
  public_subnet_cidrs   = var.aws_public_subnet_cidrs
  private_subnet_cidrs  = var.aws_private_subnet_cidrs
  firewall_subnet_cidrs = var.aws_firewall_subnet_cidrs
  az_names              = var.aws_az_names
  enable_nat_gateway    = false # Not strictly needed if only S3 is accessed via public endpoint from Azure
}

# NOTE: Network Firewall for general VPC protection and outbound traffic
# For inbound Veeam traffic to S3 (public endpoint), S3 bucket policy is key.
module "network_firewall" {
  source              = "./modules/network_firewall"
  vpc_id              = module.vpc.vpc_id
  firewall_subnet_ids = module.vpc.firewall_subnet_ids
  # Define rule groups and policies:
  # - Stateful rule for allowing outbound traffic to Azure Veeam server if needed
  # - Stateless rules for common protocols
  # - Rules for denying known bad IPs/traffic
  # Example: Pass in a complex map/object for rules
  firewall_rules_config = {
    stateful_rules = [
      {
        action = "PASS"
        protocol = "TCP"
        source_ip = "ANY" # Or specific trusted Azure IPs
        dest_ip = "ANY"
        dest_port = "443" # For S3, if routing through proxy
        # Add other specific rules as needed
      }
    ],
    stateless_rules = [
      # Standard allow/deny rules
    ]
  }
  # Configure logging for Network Firewall to CloudWatch Logs/S3
  logging_configuration = {
    log_type = "FLOW"
    log_destination_type = "CloudWatchLogs"
    # log_destination_arn = "arn:aws:logs:..." # Or an S3 bucket ARN
  }
}

module "s3_backup_repository" {
  source                       = "./modules/s3_backup_repository"
  bucket_name                  = "your-veeam-azure-backup-repo-${var.environment}"
  # Ensure Veeam's public IP(s) are passed here for the S3 bucket policy
  veeam_server_public_ips      = var.veeam_server_public_ips # List of IPs from Azure
  enable_object_lock           = true
  enable_versioning            = true
  enable_default_encryption    = true # SSE-S3
  # No direct lifecycle rules for S3 Glacier as Intelligent-Tiering handles it
  # We might add a final expiration if data needs to be fully deleted after X years
  intelligent_tiering_duration = 30 # Days to move to infrequent access
  # Optionally add an S3 VPC endpoint if other AWS resources need private access
  vpc_id                       = module.vpc.vpc_id
  private_subnet_ids           = module.vpc.private_subnet_ids
}

module "cloudwatch_monitoring" {
  source                     = "./modules/cloudwatch_monitoring"
  s3_bucket_name             = module.s3_backup_repository.bucket_id
  network_firewall_arn       = module.network_firewall.firewall_arn
  sns_topic_email_recipients = var.alert_email_recipients # List of emails for alerts
}