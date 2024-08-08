output "cognito_secrets_read_only_policy_arn" {
  description = "The ARN of the Cognito secrets"
  value       = aws_iam_policy.cognito_secrets_read_only_policy.arn
}