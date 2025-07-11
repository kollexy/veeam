## vpc
# variables.tf for vpc module

variable "project_name" {
  description = "Name of the project."
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, prod)."
  type        = string
}

variable "vpc_cidr_block" {
  description = "The CIDR block for the VPC."
  type        = string
}

variable "public_subnet_cidrs" {
  description = "A list of CIDR blocks for public subnets (one per AZ)."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "A list of CIDR blocks for private subnets (one per AZ)."
  type        = list(string)
}

variable "firewall_subnet_cidrs" {
  description = "A list of CIDR blocks for Network Firewall subnets (one per AZ)."
  type        = list(string)
}

variable "az_names" {
  description = "A list of Availability Zone names to deploy resources into."
  type        = list(string)
}