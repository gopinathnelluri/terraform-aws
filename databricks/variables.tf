variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "us-east-1"
}

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
  default     = "1678d72d-a4f1-4d33-b1de-563e77ba0202" # Placeholder
}
