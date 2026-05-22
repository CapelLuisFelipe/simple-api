# outputs.tf - RDS Module

output "db_instance_id" {
  description = "The RDS instance identifier"
  value       = aws_db_instance.main.id
}

output "db_instance_endpoint" {
  description = "The RDS instance endpoint (host:port)"
  value       = aws_db_instance.main.endpoint
}

output "db_instance_address" {
  description = "The RDS instance address (hostname only)"
  value       = aws_db_instance.main.address
}

output "db_instance_port" {
  description = "The RDS instance port"
  value       = aws_db_instance.main.port
}

output "db_instance_resource_id" {
  description = "The RDS instance resource ID"
  value       = aws_db_instance.main.resource_id
}

output "db_subnet_group_id" {
  description = "The DB subnet group ID"
  value       = aws_db_subnet_group.main.id
}

output "db_subnet_group_arn" {
  description = "The DB subnet group ARN"
  value       = aws_db_subnet_group.main.arn
}

output "db_name" {
  description = "The database name"
  value       = aws_db_instance.main.db_name
}

output "db_username" {
  description = "The database master username"
  value       = aws_db_instance.main.username
}
