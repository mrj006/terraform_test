data "aws_caller_identity" "current" {}

data "aws_region" "dr" {
  provider = aws.dr
}

resource "aws_kms_key" "application" {
  description             = "Encrypts ${var.name} application objects"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = var.tags
}

resource "aws_kms_alias" "application" {
  name          = "alias/${var.name}-objects"
  target_key_id = aws_kms_key.application.key_id
}

resource "aws_s3_bucket" "application" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy
  tags          = var.tags
}

resource "aws_s3_bucket_ownership_controls" "application" {
  bucket = aws_s3_bucket.application.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "application" {
  bucket = aws_s3_bucket.application.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "application" {
  bucket = aws_s3_bucket.application.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "application" {
  bucket = aws_s3_bucket.application.id

  rule {
    bucket_key_enabled = true

    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.application.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "application" {
  bucket = aws_s3_bucket.application.id

  rule {
    id     = "recover-and-archive"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}

data "aws_iam_policy_document" "application" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.application.arn,
      "${aws_s3_bucket.application.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "application" {
  bucket = aws_s3_bucket.application.id
  policy = data.aws_iam_policy_document.application.json
}

resource "aws_s3_bucket" "logs" {
  bucket        = var.log_bucket_name
  force_destroy = var.force_destroy
  tags          = var.tags
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ALB access-log delivery supports SSE-S3, not SSE-KMS.
#trivy:ignore:AVD-AWS-0132
resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expire-load-balancer-logs"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    expiration {
      days = 365
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

data "aws_iam_policy_document" "logs" {
  statement {
    sid     = "AllowLoadBalancerLogDelivery"
    actions = ["s3:PutObject"]
    resources = [
      "${aws_s3_bucket.logs.arn}/alb/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
    ]

    principals {
      type        = "Service"
      identifiers = ["logdelivery.elasticloadbalancing.amazonaws.com"]
    }
  }

  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.logs.arn,
      "${aws_s3_bucket.logs.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id
  policy = data.aws_iam_policy_document.logs.json
}

resource "aws_kms_key" "replica" {
  provider = aws.dr
  count    = var.replication_enabled ? 1 : 0

  description             = "Encrypts replicated ${var.name} application objects"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = var.tags
}

resource "aws_s3_bucket" "replica" {
  provider = aws.dr
  count    = var.replication_enabled ? 1 : 0

  bucket        = "${var.bucket_name}-${data.aws_region.dr.region}-replica"
  force_destroy = var.force_destroy
  tags          = merge(var.tags, { DisasterRecovery = "true" })
}

resource "aws_s3_bucket_ownership_controls" "replica" {
  provider = aws.dr
  count    = var.replication_enabled ? 1 : 0

  bucket = aws_s3_bucket.replica[0].id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "replica" {
  provider = aws.dr
  count    = var.replication_enabled ? 1 : 0

  bucket                  = aws_s3_bucket.replica[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "replica" {
  provider = aws.dr
  count    = var.replication_enabled ? 1 : 0

  bucket = aws_s3_bucket.replica[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "replica" {
  provider = aws.dr
  count    = var.replication_enabled ? 1 : 0

  bucket = aws_s3_bucket.replica[0].id

  rule {
    bucket_key_enabled = true

    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.replica[0].arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "replica" {
  provider = aws.dr
  count    = var.replication_enabled ? 1 : 0

  bucket = aws_s3_bucket.replica[0].id

  rule {
    id     = "recover-and-archive"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }

  depends_on = [aws_s3_bucket_versioning.replica]
}

data "aws_iam_policy_document" "replica" {
  count = var.replication_enabled ? 1 : 0

  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.replica[0].arn,
      "${aws_s3_bucket.replica[0].arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "replica" {
  provider = aws.dr
  count    = var.replication_enabled ? 1 : 0

  bucket = aws_s3_bucket.replica[0].id
  policy = data.aws_iam_policy_document.replica[0].json
}

data "aws_iam_policy_document" "replication_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "replication" {
  count = var.replication_enabled ? 1 : 0

  name               = "${var.name}-s3-replication"
  assume_role_policy = data.aws_iam_policy_document.replication_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "replication" {
  count = var.replication_enabled ? 1 : 0

  statement {
    actions = [
      "s3:GetReplicationConfiguration",
      "s3:ListBucket",
    ]
    resources = [aws_s3_bucket.application.arn]
  }

  statement {
    actions = [
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging",
    ]
    resources = ["${aws_s3_bucket.application.arn}/*"]
  }

  statement {
    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateTags",
    ]
    resources = ["${aws_s3_bucket.replica[0].arn}/*"]
  }

  statement {
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey",
    ]
    resources = [
      aws_kms_key.application.arn,
      aws_kms_key.replica[0].arn,
    ]
  }
}

resource "aws_iam_role_policy" "replication" {
  count = var.replication_enabled ? 1 : 0

  name   = "replicate-objects"
  role   = aws_iam_role.replication[0].id
  policy = data.aws_iam_policy_document.replication[0].json
}

resource "aws_s3_bucket_replication_configuration" "application" {
  count = var.replication_enabled ? 1 : 0

  role   = aws_iam_role.replication[0].arn
  bucket = aws_s3_bucket.application.id

  rule {
    id     = "cross-region-disaster-recovery"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.replica[0].arn
      storage_class = "STANDARD_IA"

      encryption_configuration {
        replica_kms_key_id = aws_kms_key.replica[0].arn
      }
    }

    source_selection_criteria {
      sse_kms_encrypted_objects {
        status = "Enabled"
      }
    }
  }

  depends_on = [
    aws_s3_bucket_versioning.application,
    aws_s3_bucket_versioning.replica,
  ]
}