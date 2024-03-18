locals {
  runtime = "python3.12"
}

resource "aws_cognito_user_pool" "user_pool" {
  name = "self-order-management"

  admin_create_user_config {
    allow_admin_create_user_only = true
  }

  schema {
    attribute_data_type = "String"
    name                = "CPF"
    required            = false

    string_attribute_constraints {
      min_length = 11
      max_length = 11
    }
  }

  lambda_config {
    define_auth_challenge = module.lambda_auth_challenge.lambda_function_arn
  }

  tags = var.tags

  depends_on = [
    module.lambda_auth_challenge
  ]
}

resource "aws_cognito_user_group" "admin" {
  name         = "admin"
  user_pool_id = aws_cognito_user_pool.user_pool.id

  depends_on = [
    aws_cognito_user_pool.user_pool
  ]
}

resource "aws_cognito_user_group" "customer" {
  name         = "customer"
  user_pool_id = aws_cognito_user_pool.user_pool.id

  depends_on = [
    aws_cognito_user_pool.user_pool
  ]
}

resource "aws_cognito_user_pool_client" "client" {
  name = "client"

  user_pool_id = aws_cognito_user_pool.user_pool.id
}

module "lambda_auth_sign_up" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "7.2.2"

  function_name = "auth-sign-up"
  handler       = "lambda_function.lambda_handler"
  runtime       = local.runtime

  source_path = "../src/sign-up"

  environment_variables = {
    USER_POOL_ID = aws_cognito_user_pool.user_pool.id
  }

  attach_policy_statements = true
  policy_statements = {
    cognito = {
      effect    = "Allow"
      actions   = ["cognito-idp:AdminCreateUser"]
      resources = [aws_cognito_user_pool.user_pool.arn]
    }
  }

  tags = var.tags

  depends_on = [
    aws_cognito_user_pool.user_pool
  ]
}

module "lambda_auth_sign_in" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "7.2.2"

  function_name = "auth-sign-in"
  handler       = "lambda_function.lambda_handler"
  runtime       = local.runtime

  source_path = "../src/sign-in"

  environment_variables = {
    USER_POOL_ID = aws_cognito_user_pool.user_pool.id
    CLIENT_ID    = aws_cognito_user_pool_client.client.id
  }

  attach_policy_statements = true
  policy_statements = {
    cognito = {
      effect    = "Allow"
      actions   = ["cognito-idp:AdminInitiateAuth"]
      resources = [aws_cognito_user_pool.user_pool.arn]
    }
  }

  tags = var.tags

  depends_on = [
    aws_cognito_user_pool.user_pool
  ]
}

module "lambda_auth_challenge" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "7.2.2"

  function_name = "auth-challenge"
  handler       = "lambda_function.lambda_handler"
  runtime       = local.runtime

  source_path = "../src/auth-challenge"

  tags = var.tags
}
