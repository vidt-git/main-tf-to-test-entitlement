variable "sse_algorithm" {
  description = "SSE algorithm for S3 encryption (e.g. AES256 or aws:kms)"
  type        = string
  default     = "AES256"
}

variable "environment" {
  description = "Deployment environment (prod, staging, dev)"
  type        = string
  default     = "dev"
}

variable "bucket_name_prefix" {
  description = "Prefix for the S3 bucket name"
  type        = string
  default     = "dev-"
}
