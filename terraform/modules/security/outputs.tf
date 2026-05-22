# outputs.tf - Security Module

output "alb_security_group_id" {
  description = "ALB Security Group ID"
  value       = aws_security_group.alb.id
}

output "ecs_security_group_id" {
  description = "ECS Security Group ID"
  value       = aws_security_group.ecs.id
}

output "rds_security_group_id" {
  description = "RDS Security Group ID"
  value       = aws_security_group.rds.id
}
