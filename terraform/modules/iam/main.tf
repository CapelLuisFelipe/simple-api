data "aws_iam_policy_document" "ecs_task_execution_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name               = "simple-api-ecs-task-execution-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Allow ECS to read Secrets Manager
resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  name = "allow-secrets-manager"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role" "ecs_task" {
  name               = "simple-api-ecs-task-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "ecs_task_observability" {
  name = "observability"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecs:DescribeServices", "ecs:ListTasks", "ecs:DescribeTasks"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["application-autoscaling:DescribeScalingActivities"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["cloudwatch:DescribeAlarmHistory", "cloudwatch:DescribeAlarms"]
        Resource = "*"
      }
    ]
  })
}
