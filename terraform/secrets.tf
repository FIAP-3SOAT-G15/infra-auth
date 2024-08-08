module "secrets_manager" {
  source  = "terraform-aws-modules/secrets-manager/aws"
  version = "1.1.2"

  name = "live/cognito"

  ignore_secret_changes   = true
  recovery_window_in_days = 0

  secret_string = jsonencode({
    "issuer-uri"  = "https://cognito-idp.${var.region}.amazonaws.com/${aws_cognito_user_pool.user_pool.id}"
    "jwk-set-uri" = "https://cognito-idp.${var.region}.amazonaws.com/${aws_cognito_user_pool.user_pool.id}/.well-known/jwks.json"
  })

  tags = var.tags
}

resource "aws_iam_policy" "cognito_secrets_read_only_policy" {
  name = "TechChallengeCognitoReadOnlyPolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue"
        ],
        Resource = module.secrets_manager.secret_arn
      }
    ]
  })
}
