terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = var.tf_version
        }
    }
}

provider "aws" {
    region = var.aws_region
}