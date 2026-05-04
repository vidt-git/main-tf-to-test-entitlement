# Copyright IBM Corp. 2025, 2026

# EC2 instance module variables

variable "name" {
  description = "Name to be used on EC2 instance created"
  type        = string
  default     = ""
}

variable "ami_id" {
  description = "ID of AMI to use for the instance. If not provided, the module will use either Amazon Linux 2 or Ubuntu based on the use_amazon_linux variable."
  type        = string
  default     = ""
}

variable "use_amazon_linux" {
  description = "Whether to use Amazon Linux 2 AMI. If false, Ubuntu 20.04 will be used. Only applies when ami_id is not provided."
  type        = bool
  default     = true
}

variable "instance_type" {
  description = "The type of instance to start"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Key name of the Key Pair to use for the instance"
  type        = string
  default     = null
}

variable "subnet_id" {
  description = "The VPC Subnet ID to launch in"
  type        = string
  default     = ""
}

variable "security_group_ids" {
  description = "A list of security group IDs to associate with"
  type        = list(string)
  default     = []
}

variable "associate_public_ip_address" {
  description = "Whether to associate a public IP address with an instance in a VPC"
  type        = bool
  default     = false
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

