output "bucket_name" {
  description = "S3 bucket holding the built React app."
  value       = aws_s3_bucket.site.bucket
}

output "cloudfront_domain_name" {
  description = "The public domain of the distribution."
  value       = aws_cloudfront_distribution.this.domain_name
}

output "distribution_id" {
  description = "Distribution ID, needed to invalidate the cache."
  value       = aws_cloudfront_distribution.this.id
}

output "distribution_arn" {
  description = "ARN of the distribution."
  value       = aws_cloudfront_distribution.this.arn
}
