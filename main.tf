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
  source      = "./terraform-rds"
  db_username = var.db_username 
  db_password = var.db_password 
}


module "ec2" {
  source = "./terraform-ec2"

  vpc_id = module.network.vpc_id

  public_subnets = module.network.public_subnets

  key_pair_name = "my-key-pair"
}