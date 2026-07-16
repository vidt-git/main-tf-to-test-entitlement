# Copyright IBM Corp. 2025, 2026

# Controls which test scenario is active for policy evaluation runs.
# Default "none" means all resources pass; set to a scenario key to
# activate exactly one fail path in isolation.
#   resource_cloudtrail_attr_fail — CloudTrail without enable_log_file_validation (resource [missing_attrs] FAIL)
#   provider_region_fail          — main provider region → ap-southeast-1 (not in allowed list) → region_validation fails (provider [missing_attrs] FAIL)
#   module_sse_fail               — S3 module with sse_algorithm = "aws:kms"; core::try returns it → != "AES256" → policy fails (module [missing_attrs] FAIL)
#   edge_case_empty_attrs         — CloudTrail with only required attrs (name + s3_bucket_name); entire optional attrs absent → core::try returns false → policy fails
#   fifo_queue_pass               — FIFO SQS queue with visibility_timeout=60; ternary resolves min=60, 60>=60 → policy passes ([conditional_ternary] PASS)
#   fifo_queue_fail               — FIFO SQS queue with visibility_timeout=30; ternary resolves min=60, 30<60  → policy fails  ([conditional_ternary] FAIL)
#   provider_ternary_fail         — main provider region → ap-southeast-1; not primary/secondary → ternary right branch → false → fails ([conditional_ternary] provider FAIL)
#   module_ternary_pass           — S3 module with environment=prod, bucket_name_prefix=prod-data; ternary → "prod-" prefix required → passes ([conditional_ternary] module PASS, apply-time)
#   module_ternary_fail              — S3 module with environment=prod, bucket_name_prefix=dev-data; ternary → "prod-" required but "dev-" found → fails ([conditional_ternary] module FAIL, apply-time)
#   ternary_null_condition_edge_case — CloudWatch log group with no log_group_class or retention_in_days; core::try defaults both → ternary resolves to compliant branch → passes ([conditional_ternary] edge case)
#   cross_ref_pass                   — CloudWatch log group + metric filter (pattern="ERROR"); cross-ref finds filter, pattern non-empty → passes ([cross_resource_reference] PASS)
#   cross_ref_fail                   — CloudWatch log group + metric filter (pattern=""); cross-ref finds filter but pattern empty → fails ([cross_resource_reference] FAIL)
#   cross_ref_edge                   — CloudWatch log group only, no metric filter; core::getresources → [] → has_filter=false → fails gracefully ([cross_resource_reference] edge case)
#   datasource_pass                  — SNS topic "us-east-1-payments" + target_region="us-east-1" tag; data source found, prefix matches → passes ([get_datasource] PASS)
#   datasource_fail                  — SNS topic "payment-alerts" + target_region="us-east-1" tag; data source found but prefix missing → fails ([get_datasource] FAIL)
#   datasource_edge                  — SNS topic with no target_region tag; filter→"NONEXISTENT"→no ds match→null→guard fires ([get_datasource] edge case)
#   op_locals_fail                   — aws_vpc with tags.Name="custom-vpc" (not in allowed_names); locals_in_op_policy fires on create → FAIL ([operations] locals)
#   op_input_fail                    — aws_iam_role with name="dev-role" (no prod- prefix); input.environment="prod" default → input_in_op_policy fires on create → FAIL ([operations] input)
#   op_diff_ops_create               — aws_kms_key created; kms_create_check fires → FAIL; kms_update_check (operations=["update"]) skipped ([operations] diff ops)
#   op_same_op_worst_fails           — aws_iam_group name="test-ops-group"; iam_group_name_pass PASS + iam_group_strict_fail FAIL; worst result wins → FAIL ([operations] same op)
variable "active_scenario" {
  description = "Test scenario to activate. 'none' = all-pass baseline."
  type        = string
  default     = "none"
}

# Variables for defining the environment
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "default"
}

variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

# Resource naming prefix for easier identification
variable "resource_prefix" {
  description = "Prefix to add to resource names for easier identification"
  type        = string
  default     = "security-compliance"
}

# Common tags to be applied to all resources
variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project   = "AWS Security Compliance"
    ManagedBy = "Terraform"
  }
}

# S3 Bucket encryption default settings
variable "s3_encryption_settings" {
  description = "Default encryption settings for S3 buckets"
  type = object({
    sse_algorithm      = string
    kms_master_key_id  = optional(string)
    bucket_key_enabled = bool
    enable_versioning  = bool
  })
  default = {
    sse_algorithm      = "AES256"
    bucket_key_enabled = true
    enable_versioning  = true
  }
}

# CloudTrail settings
variable "cloudtrail_bucket_name" {
  description = "Name of the S3 bucket for CloudTrail logs"
  type        = string
  default     = "prod-cloudtrail-logs"
}

variable "cloudtrail_log_group_name" {
  description = "Name of the CloudWatch log group for CloudTrail"
  type        = string
  default     = "security-compliance-cloudtrail-logs"
}

variable "compliance_trail_name" {
  description = "Name for the compliant CloudTrail trail"
  type        = string
  default     = "security-compliance-trail"
}

variable "non_compliant_trail_name" {
  description = "Name for the non-compliant CloudTrail trail"
  type        = string
  default     = "non-compliant-trail"
}

variable "watchdog_trail_name" {
  description = "Name for the CloudTrail trail with logging watchdog"
  type        = string
  default     = "cloudtrail-with-logging-watchdog"
}

# Network Firewall settings
variable "deploy_network_firewall" {
  description = "Whether to deploy the Network Firewall"
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "ID of the VPC where resources will be deployed"
  type        = string
  default     = ""
}

variable "firewall_subnet_ids" {
  description = "List of subnet IDs for firewall endpoints (should be in different AZs)"
  type        = list(string)
  default     = []
}

variable "firewall_name" {
  description = "Name of the Network Firewall"
  type        = string
  default     = "security-compliance-firewall"
}

variable "firewall_policy_name" {
  description = "Name of the firewall policy"
  type        = string
  default     = "security-compliance-policy"
}

variable "network_firewall_rule_groups" {
  description = "Map of rule groups to create for the Network Firewall"
  type = map(object({
    capacity = number
    type     = string
    rules = list(object({
      action           = string
      destination      = string
      destination_port = string
      protocol         = string
      direction        = string
      source_port      = string
      source           = string
    }))
  }))
  default = {}
}

variable "docdb_cluster_identifier" {
  description = "Identifier for the DocumentDB cluster"
  type        = string
  default     = "docdb-cluster"
}
variable "docdb_engine_version" {
  description = "Version of the DocumentDB engine"
  type        = string
  default     = "4.0"
}
variable "docdb_master_username" {
  description = "Master username for the DocumentDB cluster"
  type        = string
  default     = "admin"
}
variable "docdb_master_password" {
  description = "Master password for the DocumentDB cluster"
  type        = string
  default     = "ChangeMe123!"
}

variable "dynamo_table_name" {
  description = "Name of the DynamoDB table"
  type        = string
  default     = "dynamodb-test-table"
}

