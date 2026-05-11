variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "The name of the S3 bucket. Must be globally unique."
  type        = string
  default     = "ngn-test-sample-s3-bucket"
}

variable "role_name" {
  description = "The name of the IAM role."
  type        = string
  default     = "ngn-test-s3-access-role"
}

variable "kms_key_description" {
  description = "Description for the KMS key."
  type        = string
  default     = "KMS key for S3 bucket encryption"
}

# ------------------------------------------------------------------------------
# Databricks Iceberg Variables
# ------------------------------------------------------------------------------

variable "databricks_bucket_name" {
  description = "The name of the S3 bucket for Databricks managed Iceberg."
  type        = string
  default     = "ngn-databricks-iceberg-bucket"
}

variable "databricks_aws_account_id" {
  description = "The AWS account ID for Databricks (provided by Databricks for Unity Catalog)."
  type        = string
  default     = "414351767826" # Defaulting to AWS commercial Databricks account ID, but user should verify.
}

variable "databricks_external_id" {
  description = "The external ID for Databricks (provided by Databricks for Unity Catalog)."
  type        = string
  default     = "00000000-0000-0000-0000-000000000000" # Placeholder
}

# ------------------------------------------------------------------------------
# PrivateLink S3 Variables
# ------------------------------------------------------------------------------

variable "privatelink_bucket_name" {
  description = "The name of the S3 bucket for PrivateLink demo."
  type        = string
  default     = "ngn-privatelink-s3-bucket"
}

variable "vpc_cidr" {
  description = "CIDR block for the test VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the test Subnet."
  type        = string
  default     = "10.0.1.0/24"
}
