variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "public_subnet_count" {
  description = "Number of public subnets"
  default     = 2
}

variable "private_subnet_count" {
  description = "Number of private subnets"
  default     = 2
}

variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}
