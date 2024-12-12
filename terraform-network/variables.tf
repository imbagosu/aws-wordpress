variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  default     = "192.168.0.0/16"
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
  default     = "eu-central-1"
}

variable "trusted_ssh_cidr" {
  default = "0.0.0.0/0"
}

variable "public_subnets_cidr_blocks" {
  description = "List of CIDR blocks for public subnets"
  default = "192.168.0.0/16"
}
