terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "aws" {
  region = "eu-west-2"
}

module "network" {
  source = "./terraform-network"

  vpc_cidr            = "10.0.0.0/16"
  public_subnet_count = 2
}

module "rds" {
  source = "./terraform-rds"
}

module "ec2" {
  source = "./terraform-ec2"

  # Pass the VPC ID from the network module output
  vpc_id = module.network.vpc_id

  # Pass the public subnets from the network module output
  public_subnets = module.network.public_subnets

  # Provide the key pair name for SSH access
  key_pair_name = "my-key-pair"
}