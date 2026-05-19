# ==============================================================================
# AWS Infrastructure for Databricks Managed Iceberg
# ==============================================================================
# This file contains resources specifically for Databricks to use for managed
# Iceberg tables. It includes:
# 1. An S3 bucket for data storage.
# 2. An IAM role that Databricks can assume to access the bucket.
# ==============================================================================

# ==============================================================================
# SECTION 1: S3 Bucket for Databricks Iceberg
# ==============================================================================

################################################################################
# RESOURCE: aws_s3_bucket.databricks_bucket
# ------------------------------------------------------------------------------
# Purpose: To store Databricks managed Iceberg table data.
# Details: Force destroy enabled for easier cleanup in dev environments.
################################################################################
resource "aws_s3_bucket" "databricks_bucket" {
  bucket        = var.databricks_bucket_name
  force_destroy = true
}

################################################################################
# RESOURCE: aws_s3_bucket_public_access_block.databricks_bucket_block
# ------------------------------------------------------------------------------
# Purpose: To prevent any public access to the Databricks bucket (Best Practice).
# Connection: Applies to the S3 bucket created above.
################################################################################
resource "aws_s3_bucket_public_access_block" "databricks_bucket_block" {
  bucket = aws_s3_bucket.databricks_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

################################################################################
# RESOURCE: aws_s3_bucket_server_side_encryption_configuration.databricks_bucket_sse
# ------------------------------------------------------------------------------
# Purpose: Enforces server-side encryption on the Databricks bucket.
# Details: Uses standard S3 encryption (AES256).
# Connection: Applies to the S3 bucket created above.
################################################################################
resource "aws_s3_bucket_server_side_encryption_configuration" "databricks_bucket_sse" {
  bucket = aws_s3_bucket.databricks_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ==============================================================================
# SECTION 2: IAM Configuration for Databricks Access (Unity Catalog Style)
# ==============================================================================

################################################################################
# RESOURCE: aws_iam_role.databricks_role
# ------------------------------------------------------------------------------
# Purpose: IAM Role that Databricks will assume to access the S3 bucket.
# Trust Policy: Allows Databricks service to assume this role using an External ID.
# Connection: References variables for Databricks Account ID and External ID.
################################################################################
data "aws_caller_identity" "current" {}

resource "aws_iam_role" "databricks_role" {
  name = "ngn-databricks-iceberg-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${var.databricks_aws_account_id}:root",
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/ngn-databricks-iceberg-role"
          ]
        }
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.databricks_external_id
          }
        }
      }
    ]
  })
}

################################################################################
# RESOURCE: aws_iam_policy.databricks_policy
# ------------------------------------------------------------------------------
# Purpose: Defines what actions Databricks is allowed to perform on the bucket.
# Permissions: GetObject, PutObject, DeleteObject, ListBucket, GetBucketLocation.
# Connection: References the Databricks S3 bucket created above.
################################################################################
resource "aws_iam_policy" "databricks_policy" {
  name        = "ngn-databricks-iceberg-policy"
  description = "Policy for Databricks to access the Iceberg S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",

          # Optional but recommended by Databricks for File Events
          "s3:GetBucketNotification",
          "s3:PutBucketNotification"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.databricks_bucket.arn,
          "${aws_s3_bucket.databricks_bucket.arn}/*"
        ]
      },

      # Optional block: Recommended by Databricks to manage File Events (SNS/SQS) 
      # for Unity Catalog external locations. Improves ingestion performance.
      {
        Action = [
          "sns:CreateTopic",
          "sns:GetTopicAttributes",
          "sns:SetTopicAttributes",
          "sns:Subscribe",
          "sns:ListSubscriptionsByTopic",
          "sns:Publish",
          "sns:TagResource",
          "sns:UntagResource",
          "sns:DeleteTopic",
          "sns:Unsubscribe",
          "sqs:CreateQueue",
          "sqs:DeleteQueue",
          "sqs:GetQueueAttributes",
          "sqs:SetQueueAttributes",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:SendMessage",
          "sqs:TagQueue",
          "sqs:UntagQueue",
          "sqs:PurgeQueue"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      
      # Required by Databricks Unity Catalog: The role must be able to assume itself.
      {
        Action   = "sts:AssumeRole"
        Effect   = "Allow"
        Resource = aws_iam_role.databricks_role.arn
      }
    ]
  })
}

################################################################################
# RESOURCE: aws_iam_role_policy_attachment.databricks_attach
# ------------------------------------------------------------------------------
# Purpose: Connects the permissions defined in the policy to the Databricks role.
# Connection: Links aws_iam_role.databricks_role and aws_iam_policy.databricks_policy.
################################################################################
resource "aws_iam_role_policy_attachment" "databricks_attach" {
  role       = aws_iam_role.databricks_role.name
  policy_arn = aws_iam_policy.databricks_policy.arn
}
