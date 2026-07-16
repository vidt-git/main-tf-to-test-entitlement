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

# Permanent aliased provider with a region outside both primary and secondary lists.
# Harmless until a resource references it (tfpolicy only evaluates used providers).
provider "aws" {
  alias  = "fail_region"
  region = "ap-southeast-1"
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

# IAM role that forces tfpolicy to evaluate aws.fail_region (ap-southeast-1).
# Shared by provider_region_fail and provider_ternary_fail scenarios — both
# need the same disallowed region to trigger their respective policy failures.
resource "aws_iam_role" "provider_region_test" {
  count    = contains(["provider_region_fail", "provider_ternary_fail"], var.active_scenario) ? 1 : 0
  provider = aws.fail_region
  name     = "provider-region-fail-test"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# CloudTrail trail — tests DSL [missing_attrs] PASS scenario:
# core::try(attrs.enable_log_file_validation, false) returns true → policy passes.
resource "aws_cloudtrail" "compliance_trail" {
  name                          = var.compliance_trail_name
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  enable_log_file_validation    = true
  is_multi_region_trail         = true
  tags                          = local.resource_tags

  depends_on = [aws_s3_bucket_policy.cloudtrail_logs]
}

# resource "aws_cloudtrail" "non_compliant_trail" {  # scenario: resource_cloudtrail_attr_fail
#   count          = var.active_scenario == "resource_cloudtrail_attr_fail" ? 1 : 0
#   name           = var.non_compliant_trail_name
#   s3_bucket_name = aws_s3_bucket.cloudtrail_logs.id
#   tags           = local.resource_tags
#   depends_on     = [aws_s3_bucket_policy.cloudtrail_logs]
# }

# CloudTrail trail — tests DSL [missing_attrs] EDGE CASE scenario.
# Active only when active_scenario = "edge_case_empty_attrs".
# Only the two required attrs are set; the entire optional attrs block is absent.
# core::try(attrs.enable_log_file_validation, false) → false → policy fails.
resource "aws_cloudtrail" "edge_case_trail" {
  count          = var.active_scenario == "edge_case_empty_attrs" ? 1 : 0
  name           = "edge-case-trail"
  s3_bucket_name = aws_s3_bucket.cloudtrail_logs.id
  depends_on     = [aws_s3_bucket_policy.cloudtrail_logs]
}

# SQS queue — tests DSL [conditional_ternary] FAIL scenario.
# Active only when active_scenario = "fifo_queue_fail".
# FIFO queue → ternary resolves min_timeout = 60; timeout = 30 → 30 < 60 → fails.
resource "aws_sqs_queue" "fifo_non_compliant" {
  count                      = var.active_scenario == "fifo_queue_fail" ? 1 : 0
  name                       = "prod-non-compliant-queue.fifo"
  fifo_queue                 = true
  visibility_timeout_seconds = 30
  sqs_managed_sse_enabled    = true
}

# SQS queue — tests DSL [conditional_ternary] PASS scenario.
# Active only when active_scenario = "fifo_queue_pass".
# FIFO queue → ternary resolves min_timeout = 60; timeout = 60 → 60 >= 60 → passes.
resource "aws_sqs_queue" "fifo_compliant" {
  count                       = var.active_scenario == "fifo_queue_pass" ? 1 : 0
  name                        = "prod-example-queue.fifo"
  fifo_queue                  = true
  visibility_timeout_seconds  = 60
  sqs_managed_sse_enabled     = true
}

# S3 module — tests DSL [missing_attrs] MODULE PASS scenario:
# core::try(attrs.sse_algorithm, "AES256") returns "AES256" → policy passes.
module "s3_compliant" {
  source        = "./modules/s3"
  sse_algorithm = "AES256"
}

# S3 module — tests DSL [missing_attrs] MODULE FAIL scenario.
# Active only when active_scenario = "module_sse_fail".
# sse_algorithm = "aws:kms"; core::try returns it → "aws:kms" != "AES256" → policy fails.
# Note: omitting sse_algorithm can't trigger a real-run fail because Terraform
# resolves the module variable default ("AES256") before policy evaluation.
module "s3_non_compliant" {
  count         = var.active_scenario == "module_sse_fail" ? 1 : 0
  source        = "./modules/s3"
  sse_algorithm = "aws:kms"
}