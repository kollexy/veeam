# outputs.tf for s3_backup_repository module

output "bucket_id" {
  description = "The ID (name) of the S3 backup repository bucket."
  value       = aws_s3_bucket.backup_repo.id
}

output "bucket_arn" {
  description = "The ARN of the S3 backup repository bucket."
  value       = aws_s3_bucket.backup_repo.arn
}