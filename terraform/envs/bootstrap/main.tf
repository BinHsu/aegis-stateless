data "aws_caller_identity" "current" {}

locals {
  # Globally-unique bucket name. Account ID resolved at apply time so the
  # bucket name is not hardcoded in source.
  bucket_name = "${var.bucket_prefix}-${data.aws_caller_identity.current.account_id}"
}

# ---- state bucket ---------------------------------------------------------
resource "aws_s3_bucket" "tfstate" {
  bucket = local.bucket_name

  # Block accidental deletion. Bootstrap state lives locally; if this bucket
  # is destroyed, every downstream env loses its state. Lifecycle guard makes
  # the destruction explicit (operator must remove this block first).
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  # SSE-KMS with the AWS-managed `aws/s3` key. Production would migrate to a
  # customer-managed KMS key (granular key policy, cross-account access
  # control) — documented in docs/tradeoffs.md.
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = "alias/aws/s3"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---- state lock table -----------------------------------------------------
resource "aws_dynamodb_table" "tfstate_lock" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }
}
