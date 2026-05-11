# ==============================================================================
# AWS Infrastructure for Secure S3 Bucket
# ==============================================================================
# This configuration creates a secure S3 bucket with the following features:
# 1. Server-side encryption using a customer-managed KMS key.
# 2. Public access blocked completely.
# 3. An IAM role with permissions to access the bucket and use the KMS key.
#
# Integration Purpose:
# This setup ensures that data in the S3 bucket is encrypted at rest using a key
# that YOU control (KMS). The IAM role is the integration point that allows
# specific services (like EC2) to securely read/write to this bucket by granting
# them both the S3 permissions AND the KMS decrypt/encrypt permissions.
# ==============================================================================

# ==============================================================================
# SECTION 1: KMS Key Configuration
# ==============================================================================

################################################################################
# RESOURCE: aws_kms_key.s3_key
# ------------------------------------------------------------------------------
# Purpose: To provide a customer-managed key for encrypting data in the S3 bucket.
# Details: Rotates the key material automatically every year for security.
################################################################################
resource "aws_kms_key" "s3_key" {
  description             = var.kms_key_description
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

################################################################################
# RESOURCE: aws_kms_alias.s3_key_alias
# ------------------------------------------------------------------------------
# Purpose: An alias for the KMS key to make it easier to reference by name.
# Connection: Connects to the KMS key created above via target_key_id.
################################################################################
resource "aws_kms_alias" "s3_key_alias" {
  name          = "alias/s3-bucket-key"
  target_key_id = aws_kms_key.s3_key.key_id
}

# ==============================================================================
# SECTION 2: S3 Bucket Configuration
# ==============================================================================

################################################################################
# RESOURCE: aws_s3_bucket.bucket
# ------------------------------------------------------------------------------
# Purpose: To store data securely.
# Details: Force destroy enabled for easier cleanup in dev environments.
################################################################################
resource "aws_s3_bucket" "bucket" {
  bucket = var.bucket_name
  force_destroy = true
}

################################################################################
# RESOURCE: aws_s3_bucket_server_side_encryption_configuration.bucket_sse
# ------------------------------------------------------------------------------
# Purpose: Enforces server-side encryption on the bucket.
# Connection: Links the S3 bucket to the KMS key created in Section 1.
################################################################################
resource "aws_s3_bucket_server_side_encryption_configuration" "bucket_sse" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

################################################################################
# RESOURCE: aws_s3_bucket_public_access_block.bucket_block
# ------------------------------------------------------------------------------
# Purpose: To prevent any public access to the bucket (Best Practice).
# Connection: Applies to the S3 bucket created above.
################################################################################
resource "aws_s3_bucket_public_access_block" "bucket_block" {
  bucket = aws_s3_bucket.bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ==============================================================================
# SECTION 3: IAM Configuration (Access Control)
# ==============================================================================

################################################################################
# RESOURCE: aws_iam_role.role
# ------------------------------------------------------------------------------
# Purpose: A role that a service (like EC2) can assume to perform actions.
# Trust Policy: Configured to allow EC2 instances to assume this role.
################################################################################
resource "aws_iam_role" "role" {
  name = var.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

################################################################################
# RESOURCE: aws_iam_policy.policy
# ------------------------------------------------------------------------------
# Purpose: Defines what actions the role is allowed to perform.
# Permissions:
#   - S3: GetObject, PutObject, ListBucket on the specific bucket.
#   - KMS: Decrypt, GenerateDataKey on the specific key.
# Connection: References the S3 bucket and KMS key created above.
################################################################################
resource "aws_iam_policy" "policy" {
  name        = "${var.role_name}-policy"
  description = "Policy for accessing the S3 bucket and KMS key"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          aws_s3_bucket.bucket.arn,
          "${aws_s3_bucket.bucket.arn}/*"
        ]
      },
      {
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Effect   = "Allow"
        Resource = aws_kms_key.s3_key.arn
      }
    ]
  })
}

################################################################################
# RESOURCE: aws_iam_role_policy_attachment.attach
# ------------------------------------------------------------------------------
# Purpose: Connects the permissions defined in the policy to the role.
# Connection: Links aws_iam_role.role and aws_iam_policy.policy.
################################################################################
resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.policy.arn
}
