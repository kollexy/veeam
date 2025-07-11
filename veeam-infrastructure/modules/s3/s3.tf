# main.tf for s3_backup_repository module

resource "aws_s3_bucket" "backup_repo" {
  bucket = var.bucket_name
  acl    = "private" # Ensure no public access by default

  # Object Lock and Versioning are prerequisites for immutability
  object_lock_enabled = var.enable_object_lock

  tags = {
    Name        = var.bucket_name
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "VeeamBackupRepository"
  }
}

resource "aws_s3_bucket_versioning" "backup_repo_versioning" {
  bucket = aws_s3_bucket.backup_repo.id
  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# Default encryption for the bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "backup_repo_sse" {
  count  = var.enable_default_encryption ? 1 : 0
  bucket = aws_s3_bucket.backup_repo.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # Or "aws:kms" if using KMS keys
      # kms_master_key_id = "arn:aws:kms:..." # If using KMS
    }
  }
}

# Intelligent Tiering for 2-year retention
resource "aws_s3_bucket_intelligent_tiering_configuration" "backup_repo_tiering" {
  bucket = aws_s3_bucket.backup_repo.id
  name   = "VeeamBackupIntelligentTiering"
  status = "Enabled"

  tiering {
    access_tier = "ARCHIVE_ACCESS" # Corresponds to S3 Glacier Flexible Retrieval
    days        = 90 # Transition after 90 days of no access
  }
  tiering {
    access_tier = "DEEP_ARCHIVE_ACCESS" # Corresponds to S3 Glacier Deep Archive
    days        = 180 # Transition after 180 days of no access
  }
  # No "expiration" tiering here. Intelligent-Tiering automatically manages up to two archive tiers.
  # For the 2-year retention, the final expiration will be managed by a lifecycle rule if necessary,
  # but Veeam's own retention combined with Object Lock and Intelligent-Tiering might be sufficient.
}

# S3 Lifecycle for final expiration (if data needs to be deleted after 2 years explicitly)
resource "aws_s3_bucket_lifecycle_configuration" "backup_repo_lifecycle" {
  bucket = aws_s3_bucket.backup_repo.id

  rule {
    id     = "delete_after_2_years"
    status = "Enabled"

    # This rule will expire objects after 2 years (730 days).
    # Objects will be automatically moved by Intelligent-Tiering first.
    expiration {
      days = 730
    }
    # Note: If object lock is enabled, objects cannot be deleted until their lock period expires,
    # even if a lifecycle rule dictates deletion. The lifecycle rule will apply *after* object lock expires.
  }
}

# S3 Bucket Policy to restrict access to Veeam's public IPs
resource "aws_s3_bucket_policy" "backup_repo_policy" {
  bucket = aws_s3_bucket.backup_repo.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowVeeamAccessFromAzure"
        Effect    = "Allow"
        Principal = "*" # Veeam will use an IAM User/Role, but SourceIp can restrict to specific IPs
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject",
          "s3:PutObjectTagging",
          "s3:GetObjectTagging",
          "s3:PutBucketVersioning",
          "s3:GetBucketVersioning",
          "s3:PutBucketObjectLockConfiguration",
          "s3:GetObjectLockConfiguration",
          "s3:BypassGovernanceRetention" # If you use Governance mode; for Compliance, this is implicitly not bypassable
        ]
        Resource = [
          aws_s3_bucket.backup_repo.arn,
          "${aws_s3_bucket.backup_repo.arn}/*"
        ]
        Condition = {
          IpAddress = {
            "aws:SourceIp" = var.veeam_server_public_ips # List of allowed public IPs
          }
        }
      },
      {
        Sid       = "DenyPublicReadWrite"
        Effect    = "Deny"
        Principal = "*"
        Action    = ["s3:*"]
        Resource = [
          aws_s3_bucket.backup_repo.arn,
          "${aws_s3_bucket.backup_repo.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          },
          NotIpAddress = {
            "aws:SourceIp" = var.veeam_server_public_ips
          }
        }
      }
    ]
  })
}

# S3 VPC Endpoint (Gateway Type) for private access from within the AWS VPC to S3
# This allows any AWS resources (e.g., an EC2 instance for restores) within your VPC
# to access S3 without traversing the public internet or NAT Gateway.
resource "aws_vpc_endpoint" "s3_gateway" {
  vpc_id       = var.vpc_id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3" # Dynamic service name
  vpc_endpoint_type = "Gateway"

  # Associate with the private route table so private subnets can use it
  route_table_ids = [var.private_route_table_id]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [
          aws_s3_bucket.backup_repo.arn,
          "${aws_s3_bucket.backup_repo.arn}/*"
        ]
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-s3-vpc-endpoint"
    Environment = var.environment
    Project     = var.project_name
  }
}

data "aws_region" "current" {}

# Optional: Cross-Region Replication for Disaster Recovery
resource "aws_s3_bucket_replication_configuration" "replication" {
  count = var.enable_cross_region_replication ? 1 : 0
  role  = aws_iam_role.s3_replication_role[0].arn # IAM role for replication

  bucket = aws_s3_bucket.backup_repo.id

  rule {
    id     = "VeeamBackupCRR"
    status = "Enabled"

    filter {
      prefix = "" # Replicate all objects
    }

    destination {
      bucket        = var.replication_destination_bucket_arn
      storage_class = "INTELLIGENT_TIERING" # Match source bucket tiering
      # If you need KMS encryption in destination, specify `kms_key_id`
    }
  }
}

resource "aws_iam_role" "s3_replication_role" {
  count = var.enable_cross_region_replication ? 1 : 0
  name  = "${var.project_name}-${var.environment}-s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-s3-replication-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_iam_role_policy" "s3_replication_policy" {
  count = var.enable_cross_region_replication ? 1 : 0
  name  = "${var.project_name}-${var.environment}-s3-replication-policy"
  role  = aws_iam_role.s3_replication_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Resource = [aws_s3_bucket.backup_repo.arn]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersion",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Resource = "${aws_s3_bucket.backup_repo.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Resource = "${var.replication_destination_bucket_arn}/*"
      }
      # If KMS encryption is used on source/destination buckets, add KMS permissions here
    ]
  })
}