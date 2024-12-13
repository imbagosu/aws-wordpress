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
  region = "eu-central-1"
}

module "network" {
  source              = "./terraform-network"
  vpc_cidr            = "192.168.0.0/16"
  public_subnet_count = 2
}

module "rds" {
  source                = "./terraform-rds"
  db_username           = "wordpress_user"
  db_password           = var.db_password
  private_subnets       = module.network.private_subnets
  vpc_id                = module.network.vpc_id
  ec2_security_group_id = module.ec2.ec2_security_group_id
}



module "ec2" {
  source = "./terraform-ec2"

  vpc_id = module.network.vpc_id

  public_subnets = module.network.public_subnets

  key_pair_name = "my-key-pari"

  db_name = "wordpress"
  db_endpoint = module.rds.rds_endpoint
  db_username = module.rds.rds_username
  db_password = module.rds.rds_password
}

module "iam" {
  source         = "./terraform-iam"
  s3_bucket_name = "wordpress-bucket"
  region         = "eu-central-1"
}
