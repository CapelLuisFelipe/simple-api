# locals.tf - Dev Environment Locals

locals {
  common_tags = {
    Environment = var.environment
    Project     = "simple-api"
    ManagedBy   = "Terraform"
  }
}
