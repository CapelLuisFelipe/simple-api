data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# ============================================================================
# NETWORK MODULE - VPC, Subnets, NAT Gateway, Route Tables
# ============================================================================
module "network" {
  source = "../../modules/network"

  vpc_cidr              = var.vpc_cidr
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  enable_nat_gateway    = true
  environment           = var.environment

  tags = local.common_tags
}

# ============================================================================
# SECURITY MODULE - Security Groups (ALB, ECS, RDS)
# ============================================================================
module "security" {
  source = "../../modules/security"

  vpc_id      = module.network.vpc_id
  environment = var.environment

  tags = local.common_tags
}

# ============================================================================
# IAM MODULE - Roles for ECS tasks
# ============================================================================
module "iam" {
  source = "../../modules/iam"

  environment = var.environment

  tags = local.common_tags
}

# ============================================================================
# RDS MODULE - PostgreSQL Database (Private)
# ============================================================================
module "rds" {
  source = "../../modules/rds"

  identifier        = var.rds_identifier
  engine_version    = var.rds_engine_version
  instance_class    = var.rds_instance_class
  database_name     = var.db_name
  master_username   = var.db_username
  master_password   = var.db_password
  subnet_ids        = module.network.private_subnet_ids
  security_group_ids = [module.security.rds_security_group_id]
  allocated_storage  = var.rds_allocated_storage
  multi_az          = var.rds_multi_az
  backup_retention_period = var.rds_backup_retention
  skip_final_snapshot = var.rds_skip_final_snapshot
  deletion_protection = var.rds_deletion_protection
  publicly_accessible = false

  tags = local.common_tags
}

# ============================================================================
# CloudWatch Log Group for ECS
# ============================================================================
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/simple-api"
  retention_in_days = 7

  tags = local.common_tags
}

# ============================================================================
# ECR REPOSITORY - Docker Image Registry
# ============================================================================
resource "aws_ecr_repository" "main" {
  name                 = var.ecr_repository_name
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

# ============================================================================
# ALB MODULE - Application Load Balancer
# ============================================================================
module "alb" {
  source = "../../modules/alb"

  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  security_group_id = module.security.alb_security_group_id
  target_port       = 3000

  tags = local.common_tags
}

# ============================================================================
# ECS CLUSTER & SERVICE
# ============================================================================
resource "aws_ecs_cluster" "main" {
  name = "simple-api-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.common_tags
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "main" {
  family                   = "simple-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = module.iam.ecs_task_execution_role_arn
  task_role_arn            = module.iam.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "simple-api"
      image     = "${aws_ecr_repository.main.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "API_PORT"
          value = "3000"
        },
        {
          name  = "DB_DATABASE"
          value = var.db_name
        },
        {
          name  = "DB_USER"
          value = var.db_username
        },
        {
          name  = "DB_HOST"
          value = module.rds.db_instance_address
        },
        {
          name  = "DB_PORT"
          value = tostring(module.rds.db_instance_port)
        }
      ]
      secrets = [
        {
          name      = "DB_PASSWORD"
          valueFrom = aws_secretsmanager_secret.db_password.arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = local.common_tags
}

# Secrets Manager para DB Password
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "simple-api/db-password"
  recovery_window_in_days = 7

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = var.db_password
}

# ECS Service
resource "aws_ecs_service" "main" {
  name            = "simple-api-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = var.ecs_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.network.private_subnet_ids
    security_groups  = [module.security.ecs_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = module.alb.target_group_arn
    container_name   = "simple-api"
    container_port   = 3000
  }

  depends_on = [
    module.alb,
    aws_ecs_task_definition.main
  ]

  tags = local.common_tags
}

# ============================================================================
# AUTO SCALING for ECS Service
# ============================================================================
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = var.ecs_max_capacity
  min_capacity       = var.ecs_min_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.main.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_policy_cpu" {
  name               = "simple-api-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

resource "aws_appautoscaling_policy" "ecs_policy_memory" {
  name               = "simple-api-memory-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = 80.0
  }
}

# ============================================================================
# CI/CD MODULE - CodePipeline + CodeBuild
# ============================================================================
module "cicd" {
  source = "../../modules/cicd"

  environment             = var.environment
  ecr_repository_url      = aws_ecr_repository.main.repository_url
  ecr_repository_name     = var.ecr_repository_name
  ecs_cluster_name        = aws_ecs_cluster.main.name
  ecs_service_name        = aws_ecs_service.main.name
  github_repo             = var.github_repo
  github_branch           = var.github_branch
  codestar_connection_arn = var.codestar_connection_arn

  tags = local.common_tags
}