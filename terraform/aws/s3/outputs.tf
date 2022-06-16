output "arn" {
  description = "Bucket ARN."
  value       = aws_s3_bucket.bucket.arn
}

output "name" {
  description = "Bucket name."
  value       = aws_s3_bucket.bucket.bucket
}
