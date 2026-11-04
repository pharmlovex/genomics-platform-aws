output "state_bucket" {
  description = "Put this in infra/envs/dev/backend.hcl."
  value       = aws_s3_bucket.state.bucket
}

output "ci_plan_role_arn" {
  description = "GitHub secret AWS_PLAN_ROLE_ARN."
  value       = aws_iam_role.ci_plan.arn
}

output "ci_apply_role_arn" {
  description = "GitHub secret AWS_APPLY_ROLE_ARN."
  value       = aws_iam_role.ci_apply.arn
}
