# variables.tf - Security Module

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
