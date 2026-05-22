variable "environment" {
  type = string
}

variable "ecr_repository_url" {
  type = string
}

variable "ecr_repository_name" {
  type = string
}

variable "ecs_cluster_name" {
  type = string
}

variable "ecs_service_name" {
  type = string
}

variable "github_repo" {
  description = "GitHub repo in format owner/repo"
  type        = string
}

variable "github_branch" {
  description = "Branch to track"
  type        = string
  default     = "main"
}

variable "codestar_connection_arn" {
  description = "CodeStar connection ARN for GitHub"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
