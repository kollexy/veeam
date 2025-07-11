# variables.tf for s3_backup_repository module

variable "project_name" {
  description = "Name of the project."
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, prod)."
  type        = string
}

variable "bucket_name" {
  description = "The name of the S3 bucket to create."
  type        = string
}

variable "veeam_server_public_ips" {
  description = "List of public IP addresses of the Veeam Backup Server in Azure for S3 bucket policy."
  type        = list(string)
}

variable "enable_object_lock" {
  description = "Set to true to enable S3 Object Lock on the bucket. Requires versioning."
  type        = bool
  default     = true
}

variable "enable_versioning" {
  description = "Set to true to enable versioning on the S3 bucket. Required for Object Lock."
  type        = bool
  default     = true
}

variable "enable_default_encryption" {
  description = "Set to true to enable default S3 server-side encryption (SSE-S3)."
  type        = bool
  default     = true
}

variable "intelligent_tiering_duration" {
  description = "Number of days after which to transition objects to S3 Intelligent-Tiering Infrequent Access tier."
  type        = number
  default     = 30 # For S3-IA
}

variable "vpc_id" {
  description = "The ID of the VPC for the S3 VPC Endpoint."
  type        = string
}

variable "private_route_table_id" {
  description = "The ID of the private route table to associate with the S3 VPC Endpoint."
  type        = string
}

variable "enable_cross_region_replication" {
  description = "Set to true to enable Cross-Region Replication (CRR)."
  type        = bool
  default     = false
}

variable "replication_destination_bucket_arn" {
  description = "ARN of the destination S3 bucket for Cross-Region Replication."
  type        = string
  default     = null # Required if enable_cross_region_replication is true
}