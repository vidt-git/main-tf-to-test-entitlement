# Copyright IBM Corp. 2025, 2026

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

