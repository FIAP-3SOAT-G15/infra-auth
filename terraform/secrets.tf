module "cognito_ssm_param" {
  source = "terraform-aws-modules/ssm-parameter/aws"
  name   = "/live/cognito"
  type   = "String"

  value = jsonencode({
    "issueruri": "https://cognito-idp.${var.region}.amazonaws.com/${aws_cognito_user_pool.user_pool.id}"
    "jwkseturi": "https://cognito-idp.${var.region}.amazonaws.com/${aws_cognito_user_pool.user_pool.id}/.well-known/jwks.json"
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
          "ssm:GetParameter",
        ]
        Resource = module.cognito_ssm_param.ssm_parameter_arn
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters"
        ]
        Resource = "arn:aws:ssm:us-east-1:202062340677:*"
      }
    ]
  })
}
