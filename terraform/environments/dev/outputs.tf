output "aws_account_id" {
  description = "AWS account ID where Terraform is being executed."
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS region where Terraform is being executed."
  value       = data.aws_region.current.name
}