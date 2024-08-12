data "aws_caller_identity" "current" {}

# IAM Role for Lambda Execution
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# IAM Policy for Lambda to interact with DynamoDB
resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name = "LambdaDynamoDBPolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "dynamodb:PutItem"
      ]
      Effect   = "Allow"
      Resource = aws_dynamodb_table.marketing_interests.arn
    }]
  })
}

# Attach IAM Policies to Lambda Role
resource "aws_iam_policy_attachment" "lambda_exec_attach" {
  name       = "lambda_exec_attach"
  roles      = [aws_iam_role.lambda_exec.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy_attachment" "lambda_dynamodb_attach" {
  name       = "lambda_dynamodb_attach"
  roles      = [aws_iam_role.lambda_exec.name]
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}

# DynamoDB Table
resource "aws_dynamodb_table" "marketing_interests" {
  name         = "MarketingInterests"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "Email"

  attribute {
    name = "Email"
    type = "S"
  }
}

# Lambda Functions
data "archive_file" "validate_data" {
  type        = "zip"
  source_file = "${path.module}/functions/validate_data.py"
  output_path = "${path.module}/functions/validate_data.zip"
}

resource "aws_lambda_layer_version" "validate_data_layer" {
  layer_name          = "validate_data-layer"
  filename            = data.archive_file.validate_data.output_path
  compatible_runtimes = ["python3.9", "python3.8", "python3.7", "python3.6"]
}

resource "aws_lambda_function" "validate_data" {
  filename         = data.archive_file.validate_data.output_path
  function_name    = "validate_data"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "validate_data.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.validate_data.output_base64sha256
  layers           = [aws_lambda_layer_version.validate_data_layer.arn]
}



data "archive_file" "remove_duplicates" {
  type        = "zip"
  source_file = "${path.module}/functions/remove_duplicates.py"
  output_path = "${path.module}/functions/remove_duplicates.zip"
}
resource "aws_lambda_layer_version" "remove_duplicates_layer" {
  layer_name          = "remove_duplicates-layer"
  filename            = data.archive_file.remove_duplicates.output_path
  compatible_runtimes = ["python3.9", "python3.8", "python3.7", "python3.6"]
}
resource "aws_lambda_function" "remove_duplicates" {
  filename         = data.archive_file.remove_duplicates.output_path
  function_name    = "remove_duplicates"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "remove_duplicates.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.remove_duplicates.output_base64sha256
  layers           = [aws_lambda_layer_version.remove_duplicates_layer.arn]
}

data "archive_file" "store_marketing" {
  type        = "zip"
  source_file = "${path.module}/functions/store_marketing.py"
  output_path = "${path.module}/functions/store_marketing.zip"
}

resource "aws_lambda_layer_version" "store_marketing_layer" {
  layer_name          = "store_marketing-layer"
  filename            = data.archive_file.store_marketing.output_path
  compatible_runtimes = ["python3.9", "python3.8", "python3.7", "python3.6"]
}
resource "aws_lambda_function" "store_marketing" {
  filename      = data.archive_file.store_marketing.output_path
  function_name = "store_marketing"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "store_marketing.lambda_handler"
  runtime       = "python3.9"
  layers        = [aws_lambda_layer_version.store_marketing_layer.arn]
  environment {
    variables = {
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.marketing_interests.name
    }
  }
  source_code_hash = data.archive_file.store_marketing.output_base64sha256
}

# IAM Role for Step Functions to Invoke Lambda Functions
resource "aws_iam_role" "step_function_role" {
  name = "StepFunctionExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "states.eu-west-1.amazonaws.com"
      }
    }]
  })

  inline_policy {
    name = "StepFunctionInvokeLambda"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect = "Allow"
        Action = "lambda:InvokeFunction"
        Resource = [
          aws_lambda_function.validate_data.arn,
          aws_lambda_function.remove_duplicates.arn,
          aws_lambda_function.store_marketing.arn
        ]
      }]
    })
  }
}

# Step Functions State Machine
resource "aws_sfn_state_machine" "marketing_preferences" {
  name     = "MarketingPreferencesStateMachine"
  role_arn = aws_iam_role.step_function_role.arn
  definition = jsonencode({
    StartAt = "ValidateData",
    States = {
      ValidateData = {
        Type     = "Task",
        Resource = aws_lambda_function.validate_data.arn,
        Next     = "RemoveDuplicates"
      },
      RemoveDuplicates = {
        Type     = "Task",
        Resource = aws_lambda_function.remove_duplicates.arn,
        Next     = "StoreMarketingInterests"
      },
      StoreMarketingInterests = {
        Type     = "Task",
        Resource = aws_lambda_function.store_marketing.arn,
        End      = true
      }
    }
  })
}

# IAM Role for API Gateway to Invoke Step Functions
resource "aws_iam_role" "api_gateway_role" {
  name = "APIGatewayRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "apigateway.amazonaws.com"
      }
    }]
  })

  inline_policy {
    name = "APIGatewayInvokeStepFunctions"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect   = "Allow"
        Action   = "states:StartExecution"
        Resource = aws_sfn_state_machine.marketing_preferences.arn
      }]
    })
  }
}

# API Gateway (REST API Type)
resource "aws_api_gateway_rest_api" "api_gateway" {
  name        = "MarketingPreferencesAPI"
  description = "API Gateway for invoking Step Functions"
}

# Resource for the REST API
resource "aws_api_gateway_resource" "api_resource" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = "processdata"
}

# Method for the REST API
resource "aws_api_gateway_method" "post_method" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.api_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

# Integration with Step Functions
resource "aws_api_gateway_integration" "step_function_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api_gateway.id
  resource_id             = aws_api_gateway_resource.api_resource.id
  http_method             = aws_api_gateway_method.post_method.http_method
  type                    = "AWS"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${var.region}:states:action/StartExecution"
  credentials             = aws_iam_role.api_gateway_role.arn

  passthrough_behavior = "WHEN_NO_MATCH"
}

# Deployment of the API Gateway
resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  depends_on  = [aws_api_gateway_integration.step_function_integration]

  lifecycle {
    create_before_destroy = true
  }
}

# Stage for the REST API
resource "aws_api_gateway_stage" "api_stage" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  stage_name    = "dev"
}

output "api_endpoint" {
  value = aws_api_gateway_stage.api_stage.invoke_url
}