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
  # Switch to ap-southeast-1 for provider fail scenarios; all others use the workspace variable.
  region = contains(["provider_region_fail", "provider_ternary_fail"], var.active_scenario) ? "ap-southeast-1" : var.region
}

# provider "aws" {  # scenario: provider_region_fail / provider_ternary_fail
#   alias  = "fail_region"
#   region = "ap-southeast-1"
# }

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

# resource "aws_iam_role" "provider_region_test" {  # no longer needed: provider region is now conditional
#   count    = contains(["provider_region_fail", "provider_ternary_fail"], var.active_scenario) ? 1 : 0
#   provider = aws.fail_region
#   name     = "provider-region-fail-test"
#   ...
# }

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

# S3 module — tests DSL [conditional_ternary] MODULE FAIL scenario.
# Active only when active_scenario = "module_ternary_fail".
# environment=prod → ternary → required_prefix="prod-"; bucket_name_prefix="dev-data" fails.
# Evaluated at apply time (module_policy attrs not available at plan).
module "s3_prod_non_compliant" {
  count              = var.active_scenario == "module_ternary_fail" ? 1 : 0
  source             = "./modules/s3"
  sse_algorithm      = "AES256"
  environment        = "prod"
  bucket_name_prefix = "dev-data"
}

# S3 module — tests DSL [conditional_ternary] MODULE PASS scenario.
# Active only when active_scenario = "module_ternary_pass".
# environment=prod → ternary → required_prefix="prod-"; bucket_name_prefix="prod-data" passes.
# Evaluated at apply time (module_policy attrs not available at plan).
module "s3_prod_compliant" {
  count              = var.active_scenario == "module_ternary_pass" ? 1 : 0
  source             = "./modules/s3"
  sse_algorithm      = "AES256"
  environment        = "prod"
  bucket_name_prefix = "prod-data"
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

# CloudWatch log group — tests DSL [conditional_ternary] EDGE CASE scenario.
# Active only when active_scenario = "ternary_null_condition_edge_case".
# Neither log_group_class nor retention_in_days is set:
#   log_group_class absent   → core::try → "STANDARD" → ternary → min_retention=30
#   retention_in_days absent → core::try → 0 (never expire) → 0==0 → is_compliant=true → PASS
resource "aws_cloudwatch_log_group" "ternary_null_condition_edge_case" {
  count = var.active_scenario == "ternary_null_condition_edge_case" ? 1 : 0
  name  = "edge-case-null-ternary-condition"
}

# Companion metric filter for the ternary edge case log group.
# Required so metric_filter_cross_ref policy also passes for this scenario.
resource "aws_cloudwatch_log_metric_filter" "ternary_edge_case" {
  count          = var.active_scenario == "ternary_null_condition_edge_case" ? 1 : 0
  name           = "ternary-edge-case-filter"
  pattern        = "ERROR"
  log_group_name = "edge-case-null-ternary-condition"
  metric_transformation {
    name      = "ErrorCount"
    namespace = "TernaryEdgeCase"
    value     = "1"
  }
}

# ─── [cross_resource_reference] scenarios ────────────────────────────────────

# PASS: log group + metric filter with non-empty pattern.
# core::getresources finds the filter → has_filter=true, pattern="ERROR" → PASS.
resource "aws_cloudwatch_log_group" "cross_ref_pass" {
  count = var.active_scenario == "cross_ref_pass" ? 1 : 0
  name  = "cross-ref-pass-group"
}

resource "aws_cloudwatch_log_metric_filter" "cross_ref_pass" {
  count          = var.active_scenario == "cross_ref_pass" ? 1 : 0
  name           = "cross-ref-pass-filter"
  pattern        = "ERROR"
  log_group_name = "cross-ref-pass-group"
  metric_transformation {
    name      = "ErrorCount"
    namespace = "CrossRefTest"
    value     = "1"
  }
}

# FAIL: log group + metric filter with empty pattern.
# core::getresources finds filter → has_filter=true, pattern="" → has_pattern=false → FAIL.
resource "aws_cloudwatch_log_group" "cross_ref_fail" {
  count = var.active_scenario == "cross_ref_fail" ? 1 : 0
  name  = "cross-ref-fail-group"
}

resource "aws_cloudwatch_log_metric_filter" "cross_ref_fail" {
  count          = var.active_scenario == "cross_ref_fail" ? 1 : 0
  name           = "cross-ref-fail-filter"
  pattern        = ""
  log_group_name = "cross-ref-fail-group"
  metric_transformation {
    name      = "AllEvents"
    namespace = "CrossRefTest"
    value     = "1"
  }
}

# EDGE CASE: log group with no metric filter at all.
# core::getresources returns [] → has_filter=false → policy fails gracefully (no crash).
resource "aws_cloudwatch_log_group" "cross_ref_edge" {
  count = var.active_scenario == "cross_ref_edge" ? 1 : 0
  name  = "cross-ref-edge-group"
}

# ─── [get_datasource] scenarios ──────────────────────────────────────────────

# Always-present data source. core::getdatasource("aws_region", { name = "us-east-1" })
# resolves to this when the topic's target_region tag = "us-east-1".
# For the edge case (no tag), the filter value becomes "NONEXISTENT" and no
# data source matches → core::getdatasource returns null → guard fires.
data "aws_region" "current" {}

# PASS: topic name starts with "us-east-1-"; data source found; prefix matches.
resource "aws_sns_topic" "datasource_pass" {
  count = var.active_scenario == "datasource_pass" ? 1 : 0
  name  = "us-east-1-payments"
  tags  = { target_region = "us-east-1" }
}

# FAIL: topic name missing region prefix; data source found but regex fails.
resource "aws_sns_topic" "datasource_fail" {
  count = var.active_scenario == "datasource_fail" ? 1 : 0
  name  = "payment-alerts"
  tags  = { target_region = "us-east-1" }
}

# EDGE CASE: no target_region tag → core::try → "NONEXISTENT" → no data source
# matches filter → core::getdatasource → null → guard 1 fires with clear message.
resource "aws_sns_topic" "datasource_edge" {
  count = var.active_scenario == "datasource_edge" ? 1 : 0
  name  = "edge-no-region-tag"
}

# ─── [operations] scenarios ───────────────────────────────────────────────────

# Scenario 1 — locals used in operation-based policy (op_locals_fail).
# Active only when active_scenario = "op_locals_fail".
# aws_vpc.tags.Name = "custom-vpc" is not in local.allowed_names
# ["prod-vpc", "staging-vpc", "dev-vpc"] → locals_in_op_policy FAIL on create.
resource "aws_vpc" "op_locals_fail" {
  count      = var.active_scenario == "op_locals_fail" ? 1 : 0
  cidr_block = "10.1.0.0/16"
  tags       = merge(local.resource_tags, { Name = "custom-vpc" })
}

# Scenario 2 — input used in operation-based policy (op_input_fail).
# Active only when active_scenario = "op_input_fail".
# name = "dev-role" has no "prod-" prefix; input.environment defaults to "prod"
# → condition input.environment != "prod" || regex("^prod-", ...) = false → FAIL on create.
resource "aws_iam_role" "op_input_fail" {
  count = var.active_scenario == "op_input_fail" ? 1 : 0
  name  = "dev-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Scenario 3 — multiple policies with different operations (op_diff_ops_create).
# Active only when active_scenario = "op_diff_ops_create".
# New resource → create operation: kms_create_check fires → FAIL.
# kms_update_check (operations=["update"]) is skipped entirely on create.
resource "aws_kms_key" "op_diff_ops" {
  count       = var.active_scenario == "op_diff_ops_create" ? 1 : 0
  description = "op-diff-ops-test-key"
}

# Scenario 4 — multiple policies same operation, worst result wins (op_same_op_worst_fails).
# Active only when active_scenario = "op_same_op_worst_fails".
# name = "test-ops-group" (non-empty) → iam_group_name_pass condition = true → PASS.
# iam_group_strict_fail condition = false → FAIL.
# Both policies fire on create; worst result (FAIL) determines overall outcome.
resource "aws_iam_group" "op_same_op" {
  count = var.active_scenario == "op_same_op_worst_fails" ? 1 : 0
  name  = "test-ops-group"
}