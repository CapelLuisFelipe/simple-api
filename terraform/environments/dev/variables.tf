variable "aws_region" {
  description = "AWS region where resources will be created."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "dev"
}

# ============================================================================
# NETWORK VARIABLES
# ============================================================================
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

# ============================================================================
# DATABASE VARIABLES
# ============================================================================
variable "db_name" {
  description = "Database name"
  type        = string
  default     = "simple_api"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "postgres"
  sensitive   = true
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

variable "rds_identifier" {
  description = "RDS instance identifier"
  type        = string
  default     = "simple-api-db"
}

variable "rds_engine_version" {
  description = "RDS PostgreSQL version"
  type        = string
  default     = "15.3"
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "rds_multi_az" {
  description = "Enable RDS Multi-AZ"
  type        = bool
  default     = false
}

variable "rds_backup_retention" {
  description = "RDS backup retention period in days"
  type        = number
  default     = 7
}

variable "rds_skip_final_snapshot" {
  description = "Skip final snapshot on RDS deletion"
  type        = bool
  default     = false
}

variable "rds_deletion_protection" {
  description = "Enable RDS deletion protection"
  type        = bool
  default     = true
}

# ============================================================================
# ECR VARIABLES
# ============================================================================
variable "ecr_repository_name" {
  description = "ECR repository name"
  type        = string
  default     = "simple-api"
}

# ============================================================================
# ECS VARIABLES
# ============================================================================
variable "ecs_desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 2
}

variable "ecs_min_capacity" {
  description = "Minimum capacity for ECS auto-scaling"
  type        = number
  default     = 1
}

variable "ecs_max_capacity" {
  description = "Maximum capacity for ECS auto-scaling"
  type        = number
  default     = 4
}

# ============================================================================
# CI/CD VARIABLES
# ============================================================================
variable "github_repo" {
  description = "GitHub repository in format owner/repo"
  type        = string
}

variable "github_branch" {
  description = "Branch to trigger the pipeline"
  type        = string
  default     = "main"
}

variable "codestar_connection_arn" {
  description = "ARN of the CodeStar connection to GitHub (created manually in AWS console)"
  type        = string
}