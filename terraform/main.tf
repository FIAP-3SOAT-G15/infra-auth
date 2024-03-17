module "lambda_sign_up" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "7.2.2"

  function_name = "sign-up"
  handler       = "index.lambda_handler"
  runtime       = "python3.12"

  source_path = "../src/sign-up"

  tags = var.tags
}

module "lambda_sign_in" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "7.2.2"

  function_name = "sign-in"
  handler       = "index.lambda_handler"
  runtime       = "python3.12"

  source_path = "../src/sign-in"

  tags = var.tags
}

module "lambda_auth_challenge" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "7.2.2"

  function_name = "auth-challenge"
  handler       = "index.lambda_handler"
  runtime       = "python3.12"

  source_path = "../src/auth-challenge"

  tags = var.tags
}
