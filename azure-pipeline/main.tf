# main.tf

# Configure the AWS provider
provider "aws" {
  region = "eu-west-2" # Choose your desired AWS region (e.g., us-east-1, eu-central-1, etc.)
  # Terraform will automatically pick up AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY
  # from environment variables set by your Azure DevOps service connection.
  # Do NOT hardcode credentials here.
}

# Resource: AWS VPC
# This defines your Virtual Private Cloud.
resource "aws_vpc" "main_vpc" {
  cidr_block = "172.16.0.0/16" # The IP range for your VPC
  enable_dns_support = true   # Enables DNS resolution for instances in the VPC
  enable_dns_hostnames = true # Enables DNS hostnames for instances in the VPC

  tags = {
    Name        = "my-terraform-vpc"
    Environment = "Development"
    ManagedBy   = "Terraform"
  }
}
