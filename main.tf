# Copyright IBM Corp. 2025, 2026

# terraform {

#   cloud {
#     organization = "terraform-policy-test-org"
#     workspaces {
#       name = "policy-alpha-test-1"
#     }
#   }
# }

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