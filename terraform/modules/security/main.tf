# main.tf - Security Module

# ALB Security Group (expõe ao público)
resource "aws_security_group" "alb" {
  name        = "simple-api-alb-sg"
  description = "Security group for ALB"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    { Name = "simple-api-alb-sg" }
  )
}

# ALB - Allow inbound HTTP/HTTPS
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
  
  tags = merge(
    var.tags,
    { Name = "allow-http" }
  )
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
  
  tags = merge(
    var.tags,
    { Name = "allow-https" }
  )
}

# ALB - Allow outbound all
resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id
  
  from_port   = -1
  to_port     = -1
  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
  
  tags = merge(
    var.tags,
    { Name = "allow-all-outbound" }
  )
}

# ECS Security Group
resource "aws_security_group" "ecs" {
  name        = "simple-api-ecs-sg"
  description = "Security group for ECS tasks"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    { Name = "simple-api-ecs-sg" }
  )
}

# ECS - Allow inbound from ALB
resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
  security_group_id = aws_security_group.ecs.id
  
  from_port                    = 3000
  to_port                      = 3000
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id
  
  tags = merge(
    var.tags,
    { Name = "allow-from-alb" }
  )
}

# ECS - Allow outbound all
resource "aws_vpc_security_group_egress_rule" "ecs_all" {
  security_group_id = aws_security_group.ecs.id
  
  from_port   = -1
  to_port     = -1
  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
  
  tags = merge(
    var.tags,
    { Name = "allow-all-outbound" }
  )
}

# RDS Security Group
resource "aws_security_group" "rds" {
  name        = "simple-api-rds-sg"
  description = "Security group for RDS database"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    { Name = "simple-api-rds-sg" }
  )
}

# RDS - Allow inbound from ECS
resource "aws_vpc_security_group_ingress_rule" "rds_from_ecs" {
  security_group_id = aws_security_group.rds.id
  
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ecs.id
  
  tags = merge(
    var.tags,
    { Name = "allow-from-ecs" }
  )
}

# RDS - Allow outbound all (geralmente bloqueado, mas deixamos para flexibilidade)
resource "aws_vpc_security_group_egress_rule" "rds_all" {
  security_group_id = aws_security_group.rds.id
  
  from_port   = -1
  to_port     = -1
  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
  
  tags = merge(
    var.tags,
    { Name = "allow-all-outbound" }
  )
}
