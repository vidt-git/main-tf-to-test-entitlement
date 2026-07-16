variable "sse_algorithm" {
  description = "SSE algorithm for S3 encryption (e.g. AES256 or aws:kms)"
  type        = string
  default     = "AES256"
}
