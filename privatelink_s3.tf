# ==============================================================================
# AWS Infrastructure for PrivateLink S3 Demo
# ==============================================================================
# 🎡 THE AMUSEMENT PARK STORY (How this works)
# ------------------------------------------------------------------------------
# 1. The VPC (Your Amusement Park): The giant area you bought and fenced.
# 2. The Subnet (Space Land): A specific themed land inside the park.
# 3. The S3 Bucket (The Ice Cream Factory): Located outside the park.
# 4. PrivateLink (The Monorail): A private track from Space Land to the factory.
#
# 📝 STEP-BY-STEP WHAT WE ARE DOING HERE:
# ------------------------------------------------------------------------------
# Step 1: Building the Base (Network)
#   - aws_vpc: Creates the amusement park land (VPC).
#   - aws_subnet: Creates "Space Land" (Subnet) inside the park.
#
# Step 2: Creating the Storage (S3 & Security)
#   - aws_kms_key: Creates a secret decoder ring (encryption key).
#   - aws_s3_bucket: Builds the Ice Cream Factory (S3 bucket).
#   - aws_s3_bucket_server_side_encryption_configuration: Enforces the lock.
#   - aws_s3_bucket_public_access_block: Blocks the public from walking in.
#
# Step 3: Building the Tunnel (PrivateLink)
#   - aws_vpc_endpoint: Builds the Monorail Track (VPC Endpoint).
#   - aws_security_group: Puts a security guard at the monorail station.
#
# Step 4: Enforcing the Rules (Bucket Policy)
#   - aws_s3_bucket_policy: Rule at the factory door saying "Monorail Only!".
# ==============================================================================

# ==============================================================================
# SECTION 1: Network Infrastructure
# ==============================================================================

################################################################################
# RESOURCE: aws_vpc.test_vpc
# ------------------------------------------------------------------------------
# Purpose: Isolated network for the test environment.
################################################################################
resource "aws_vpc" "test_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "ngn-privatelink-vpc"
  }
}

################################################################################
# RESOURCE: aws_subnet.test_subnet
# ------------------------------------------------------------------------------
# Purpose: Subnet within the VPC where the endpoint will live.
################################################################################
resource "aws_subnet" "test_subnet" {
  vpc_id            = aws_vpc.test_vpc.id
  cidr_block        = var.subnet_cidr
  availability_zone = "${var.aws_region}a" # Use AZ 'a' of the region

  tags = {
    Name = "ngn-privatelink-subnet"
  }
}

# ==============================================================================
# SECTION 2: S3 and KMS Resources
# ==============================================================================

################################################################################
# RESOURCE: aws_kms_key.privatelink_key
# ------------------------------------------------------------------------------
# Purpose: KMS key for encrypting the PrivateLink S3 bucket.
################################################################################
resource "aws_kms_key" "privatelink_key" {
  description             = "KMS key for PrivateLink S3 bucket"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

################################################################################
# RESOURCE: aws_s3_bucket.privatelink_bucket
# ------------------------------------------------------------------------------
# Purpose: The S3 bucket to be accessed via PrivateLink.
################################################################################
resource "aws_s3_bucket" "privatelink_bucket" {
  bucket        = var.privatelink_bucket_name
  force_destroy = true
}

################################################################################
# RESOURCE: aws_s3_bucket_server_side_encryption_configuration.privatelink_bucket_sse
# ------------------------------------------------------------------------------
# Purpose: Enforce encryption using the KMS key.
################################################################################
resource "aws_s3_bucket_server_side_encryption_configuration" "privatelink_bucket_sse" {
  bucket = aws_s3_bucket.privatelink_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.privatelink_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

################################################################################
# RESOURCE: aws_s3_bucket_public_access_block.privatelink_bucket_block
# ------------------------------------------------------------------------------
# Purpose: Block all public access (Best Practice).
################################################################################
resource "aws_s3_bucket_public_access_block" "privatelink_bucket_block" {
  bucket = aws_s3_bucket.privatelink_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ==============================================================================
# SECTION 3: PrivateLink (VPC Endpoint)
# ==============================================================================

################################################################################
# RESOURCE: aws_vpc_endpoint.s3_interface
# ------------------------------------------------------------------------------
# Purpose: The Interface VPC Endpoint (PrivateLink) for S3.
# Details: Creates an ENI in the subnet with a private IP.
################################################################################
resource "aws_vpc_endpoint" "s3_interface" {
  vpc_id            = aws_vpc.test_vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Interface"

  subnet_ids = [aws_subnet.test_subnet.id]

  # Security Group is required for Interface Endpoints
  security_group_ids = [aws_security_group.endpoint_sg.id]

  tags = {
    Name = "ngn-s3-privatelink-endpoint"
  }
}

################################################################################
# RESOURCE: aws_security_group.endpoint_sg
# ------------------------------------------------------------------------------
# Purpose: Security Group for the VPC Endpoint to allow traffic.
################################################################################
resource "aws_security_group" "endpoint_sg" {
  name        = "ngn-endpoint-sg"
  description = "Allow traffic to S3 Endpoint"
  vpc_id      = aws_vpc.test_vpc.id

  # Allow HTTPS (443) from within the VPC
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ==============================================================================
# SECTION 4: Bucket Policy (Restricting to PrivateLink)
# ==============================================================================

################################################################################
# RESOURCE: aws_s3_bucket_policy.restrict_to_vpce
# ------------------------------------------------------------------------------
# Purpose: Denies access unless the request comes through the VPC Endpoint.
#
# ⚠️ WARNING: This will block your access from home unless you access it via
# the endpoint (which requires a VPN like Tailscale).
#
# To allow your home IP as well, you would add a condition like:
# "NotIpAddress": { "aws:SourceIp": ["YOUR_HOME_PUBLIC_IP/32"] }
################################################################################
resource "aws_s3_bucket_policy" "restrict_to_vpce" {
  bucket = aws_s3_bucket.privatelink_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "Access-to-specific-VPCE-only"
        Principal = "*"
        Action    = "s3:*"
        Effect    = "Deny"
        Resource = [
          aws_s3_bucket.privatelink_bucket.arn,
          "${aws_s3_bucket.privatelink_bucket.arn}/*"
        ]
        Condition = {
          StringNotEquals = {
            "aws:sourceVpce" = aws_vpc_endpoint.s3_interface.id
          }
        }
      }
    ]
  })
}
