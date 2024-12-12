variable "s3_bucket_name" {
  description = "Name of the S3 bucket EC2 instances can access"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}
