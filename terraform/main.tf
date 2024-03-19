locals {
  runtime = "python3.12"
}

data "terraform_remote_state" "tech-challenge" {
  backend = "s3"

  config = {
    bucket = "fiap-3soat-g15-infra-tech-challenge-state"
    key    = "live/terraform.tfstate"
    region = var.region
  }
}

data "terraform_remote_state" "rds" {
  backend = "s3"

  config = {
    bucket = "fiap-3soat-g15-infra-db-state"
    key    = "live/terraform.tfstate"
    region = var.region
  }
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

data "aws_ssm_parameter" "rds_param" {
  name = data.terraform_remote_state.rds.outputs.rds_ssm_parameter_name
}

data "aws_secretsmanager_secret" "rds_secret" {
  arn = data.terraform_remote_state.rds.outputs.db_instance_master_user_secret_arn
}

module "lambda_auth_sign_up" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "7.2.2"

  function_name = "auth-sign-up"
  handler       = "lambda_function.lambda_handler"
  runtime       = local.runtime

  source_path = {
    path             = "../src/sign-up"
    pip_requirements = true
  }

  environment_variables = {
    USER_POOL_ID  = aws_cognito_user_pool.user_pool.id
    RDS_PARAM_ID  = data.aws_ssm_parameter.rds_param.name
    RDS_SECRET_ID = data.aws_secretsmanager_secret.rds_secret.name
  }

  attach_policy_statements = true
  policy_statements = {
    cognito = {
      effect = "Allow"
      actions = [
        "cognito-idp:AdminCreateUser",
        "cognito-idp:AdminAddUserToGroup"
      ]
      resources = [
        aws_cognito_user_pool.user_pool.arn
      ]
    }
  }


  vpc_subnet_ids = data.terraform_remote_state.tech-challenge.outputs.private_subnets

  attach_policies = true
  policies = [
    data.terraform_remote_state.rds.outputs.rds_secrets_read_only_policy_arn,
    data.terraform_remote_state.rds.outputs.rds_params_read_only_policy_arn
  ]
  number_of_policies = 2

  layers = [
    # AWS Parameters and Secrets Lambda Extension for us-east-1
    # https://docs.aws.amazon.com/secretsmanager/latest/userguide/retrieving-secrets_lambda.html
    # https://docs.aws.amazon.com/systems-manager/latest/userguide/ps-integration-lambda-extensions.html#ps-integration-lambda-extensions-add
    "arn:aws:lambda:us-east-1:177933569100:layer:AWS-Parameters-and-Secrets-Lambda-Extension:11"
  ]

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
      effect = "Allow"
      actions = [
        "cognito-idp:AdminInitiateAuth"
      ]
      resources = [
        aws_cognito_user_pool.user_pool.arn
      ]
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

module "lambda_auth_authorizer" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "7.2.2"

  function_name = "auth-authorizer"
  handler       = "lambda_function.lambda_handler"
  runtime       = local.runtime

  source_path = "../src/auth-authorizer"

  environment_variables = {
    AWS_REGION   = var.region
    USER_POOL_ID = aws_cognito_user_pool.user_pool.id
    CLIENT_ID    = aws_cognito_user_pool_client.client.id
  }

  tags = var.tags
}
