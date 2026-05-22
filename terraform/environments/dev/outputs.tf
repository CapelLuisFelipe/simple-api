output "aws_account_id" {
  description = "AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS region"
  value       = data.aws_region.current.name
}

# ============================================================================
# NETWORK OUTPUTS
# ============================================================================
output "vpc_id" {
  description = "VPC ID"
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.network.private_subnet_ids
}

# ============================================================================
# DATABASE OUTPUTS
# ============================================================================
output "rds_endpoint" {
  description = "RDS endpoint (host:port)"
  value       = module.rds.db_instance_endpoint
  sensitive   = false
}

output "rds_address" {
  description = "RDS address (hostname only)"
  value       = module.rds.db_instance_address
  sensitive   = false
}

output "rds_port" {
  description = "RDS port"
  value       = module.rds.db_instance_port
}

output "rds_database_name" {
  description = "RDS database name"
  value       = module.rds.db_name
}

output "rds_username" {
  description = "RDS master username"
  value       = module.rds.db_username
  sensitive   = true
}

# ============================================================================
# ECR OUTPUTS
# ============================================================================
output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.main.repository_url
}

output "ecr_repository_arn" {
  description = "ECR repository ARN"
  value       = aws_ecr_repository.main.arn
}

# ============================================================================
# ALB OUTPUTS
# ============================================================================
output "alb_dns_name" {
  description = "ALB DNS name (access point for the API)"
  value       = module.alb.alb_dns_name
}

output "alb_arn" {
  description = "ALB ARN"
  value       = module.alb.alb_arn
}

# ============================================================================
# ECS OUTPUTS
# ============================================================================
output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.main.arn
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.main.name
}

output "ecs_task_definition_arn" {
  description = "ECS task definition ARN"
  value       = aws_ecs_task_definition.main.arn
}

# ============================================================================
# API ACCESS
# ============================================================================
output "api_url" {
  description = "API base URL"
  value       = "http://${module.alb.alb_dns_name}"
}

output "api_endpoints" {
  description = "Available API endpoints"
  value = {
    root    = "http://${module.alb.alb_dns_name}/"
    connect = "http://${module.alb.alb_dns_name}/connect"
  }
}

# ============================================================================
# CI/CD OUTPUTS
# ============================================================================
output "pipeline_name" {
  description = "CodePipeline name"
  value       = module.cicd.pipeline_name
}

output "codebuild_project_name" {
  description = "CodeBuild project name"
  value       = module.cicd.codebuild_project_name
}