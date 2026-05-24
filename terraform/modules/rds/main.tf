# main.tf - RDS Module

# DB Subnet Group (privada)
resource "aws_db_subnet_group" "main" {
  name       = "${var.identifier}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(
    var.tags,
    { Name = "${var.identifier}-subnet-group" }
  )
}

resource "aws_db_parameter_group" "main" {
  name   = "${var.identifier}-pg"
  family = "postgres15"

  parameter {
    name  = "rds.force_ssl"
    value = "0"
  }

  tags = merge(var.tags, { Name = "${var.identifier}-pg" })
}

# RDS Instance (PostgreSQL privado)
resource "aws_db_instance" "main" {
  identifier           = var.identifier
  engine               = "postgres"
  engine_version       = var.engine_version
  instance_class       = var.instance_class
  allocated_storage    = var.allocated_storage
  db_name              = var.database_name
  username             = var.master_username
  password             = var.master_password
  parameter_group_name = aws_db_parameter_group.main.name

  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = var.security_group_ids
  publicly_accessible     = var.publicly_accessible
  multi_az                = var.multi_az
  backup_retention_period = var.backup_retention_period
  skip_final_snapshot     = true
  deletion_protection     = var.deletion_protection

  # Performance Insights
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  # Enhanced Monitoring
  enabled_cloudwatch_logs_exports = ["postgresql"]

  storage_encrypted = true

  tags = merge(
    var.tags,
    { Name = var.identifier }
  )
}
