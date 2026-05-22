terraform {
  required_version = ">= 1.8.0"

  backend "s3" {
    bucket       = "simple-api-tfstate-491085390322"
    key          = "dev/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
} # triggered
