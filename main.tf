# Copyright IBM Corp. 2025, 2026

terraform {

  cloud {
    hostname = "tfcdev-79d3f120.ngrok.app"
    organization = "hashicorp"
    workspaces {
      name = "main-tf-to-test-entitlement"
    }
  }
}

provider "aws" {
  region = var.region
}

locals {
  # Create resource tags
  resource_tags = merge(
    var.common_tags,
    {
      Environment = var.environment
    }
  )
}

# # Data source to fetch available AZs in the region
# data "aws_availability_zones" "available" {
#   state = "available"
# }

# Get current account ID
# data "aws_caller_identity" "current" {}

# module "cloudfront" {
#   source = "./modules/cloudfront"
# }

# Create an EC2 instance using the new module
module "ec2_instance" {
  source        = "./modules/ec2"
  instance_type = "t2.micro"

}

# Create a DynamoDB table with autoscaling policies
# module "dynamodb_table" {
#   source = "./modules/dynamodb"
# }

# S3 bucket for CloudTrail logs
resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket = var.cloudtrail_bucket_name
  tags   = local.resource_tags
}

# Logging bucket required by the logging_bucket_validation policy
resource "aws_s3_bucket" "cloudtrail_logs_logging" {
  bucket = "${var.cloudtrail_bucket_name}-logs"
  tags   = local.resource_tags
}

resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.cloudtrail_logs.arn
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.cloudtrail_logs.arn}/AWSLogs/*"
        Condition = {
          StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" }
        }
      }
    ]
  })
}

# CloudTrail trail — tests DSL [missing_attrs]: policy uses
# core::try(attrs.enable_log_file_validation, false) and this resource
# explicitly sets it to true, so the policy should pass.
resource "aws_cloudtrail" "compliance_trail" {
  name                          = var.compliance_trail_name
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  enable_log_file_validation    = true
  is_multi_region_trail         = true
  tags                          = local.resource_tags

  depends_on = [aws_s3_bucket_policy.cloudtrail_logs]
}