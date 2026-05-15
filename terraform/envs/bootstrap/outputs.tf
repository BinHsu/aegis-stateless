output "bucket_name" {
  description = "S3 bucket holding remote Terraform state for platform/ and regional/ envs."
  value       = aws_s3_bucket.tfstate.id
}

output "dynamodb_table" {
  description = "DynamoDB table used for state locking."
  value       = aws_dynamodb_table.tfstate_lock.name
}

output "region" {
  description = "AWS region of the state backend (bucket + table both live here)."
  value       = var.platform_region
}

# Convenience output: the literal backend.hcl content that downstream envs
# pass via `terraform init -backend-config=...`. The Makefile reads this and
# writes ./backend.hcl in the repo root (gitignored — derived value).
output "backend_hcl" {
  description = "backend.hcl content for downstream envs (Makefile-consumed)."
  value       = <<-EOT
    bucket         = "${aws_s3_bucket.tfstate.id}"
    dynamodb_table = "${aws_dynamodb_table.tfstate_lock.name}"
    region         = "${var.platform_region}"
    encrypt        = true
  EOT
}
