provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "kxc-simple-api"
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = "CapelLuisFelipe"
    }
  }
}