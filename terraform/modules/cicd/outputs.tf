output "pipeline_name" {
  value = aws_codepipeline.main.name
}

output "terraform_pipeline_name" {
  value = aws_codepipeline.terraform.name
}

output "codebuild_project_name" {
  value = aws_codebuild_project.main.name
}

output "artifacts_bucket" {
  value = aws_s3_bucket.artifacts.bucket
}
