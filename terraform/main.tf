locals {
  runtime = "python3.12"
}

data "terraform_remote_state" "tech-challenge" {
  backend = "s3"

  config = {
    bucket = "fiap-3soat-g15-iac-tech-challenge"
    key    = "live/terraform.tfstate"
    region = var.region
  }
}

resource "null_resource" "always_run" {
  triggers = {
    timestamp = timestamp()
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

  schema {
    attribute_data_type = "String"
    name                = "CUSTOMER_ID"
    required            = false
  }

  lambda_config {
    define_auth_challenge = module.lambda_auth_challenge.lambda_function_arn
  }

  tags = var.tags

  depends_on = [
    module.lambda_auth_challenge
  ]

  lifecycle {
    replace_triggered_by = [
      null_resource.always_run
    ]
  }
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

data "aws_lb" "orders_load_balancer" {
  name = var.orders_load_balancer_name
}

resource "aws_security_group" "auth_sign_up" {
  name   = "auth_sign_up"
  vpc_id = data.terraform_remote_state.tech-challenge.outputs.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
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
    USER_POOL_ID      = aws_cognito_user_pool.user_pool.id
    LOAD_BALANCER_DNS = data.aws_lb.orders_load_balancer.dns_name
    TARGET_PORT       = var.target_group_port
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

  vpc_subnet_ids         = data.terraform_remote_state.tech-challenge.outputs.private_subnets
  vpc_security_group_ids = [aws_security_group.auth_sign_up.id]
  attach_network_policy  = true
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
    REGION       = var.region
    USER_POOL_ID = aws_cognito_user_pool.user_pool.id
    CLIENT_ID    = aws_cognito_user_pool_client.client.id
  }

  tags = var.tags
}
