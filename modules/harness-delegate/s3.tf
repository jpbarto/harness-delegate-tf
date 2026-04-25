# ---------------------------------------------------------------------------
# S3 bucket — CI build cache
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "ci_cache" {
  bucket = local.ci_cache_bucket_name
  tags   = merge(local.tags, { purpose = "harness-ci-cache" })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ci_cache" {
  bucket = aws_s3_bucket.ci_cache.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "ci_cache" {
  bucket                  = aws_s3_bucket.ci_cache.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Expire cache objects after 30 days to control storage costs.
resource "aws_s3_bucket_lifecycle_configuration" "ci_cache" {
  bucket = aws_s3_bucket.ci_cache.id

  rule {
    id     = "expire-cache"
    status = "Enabled"

    filter {}

    expiration {
      days = 30
    }
  }
}

# ---------------------------------------------------------------------------
# S3 bucket — Terraform state produced by Harness CD pipelines
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "tf_state" {
  bucket = local.tf_state_bucket_name
  tags   = merge(local.tags, { purpose = "harness-tf-state" })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
