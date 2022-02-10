provider "aws" {
  region = var.aws_region
  access_key = ""
  secret_key = ""
}

# DynamoDB Table with hash key 'id'
resource "aws_dynamodb_table" "VisitorCount" {
  name = "VisitorCount"
  billing_mode = "PROVISIONED"
  read_capacity = 10
  write_capacity = 10
  hash_key = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# Lambda Role
resource "aws_iam_role" "lambda_role" {
 name   = "iam_role_lambda_function"
 assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# Policy to grant Lambda function logging permissions
resource "aws_iam_policy" "lambda_logging" {

  name         = "iam_policy_lambda_logging_function"
  path         = "/"
  description  = "IAM policy for logging from a lambda"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

# Policy attachment on role
resource "aws_iam_role_policy_attachment" "policy_attach_logging" {
  role = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

# Policy to grant Lambda function permissions to update and read DynamoDB table
resource "aws_iam_policy" "lambda_dynamoDB" {
  name = "iam_policy_lambda_update_dynamoDB"
  path = "/"
  description = "IAM policy for updating dynamoDB table"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:UpdateItem",
        "dynamodb:GetRecords"
      ],
      "Resource": "${aws_dynamodb_table.VisitorCount.arn}",
      "Effect": "Allow"
    }
  ]
}
EOF
}

# Policy attachment on role
resource "aws_iam_role_policy_attachment" "policy_attach_dynamoDB" {
  role = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_dynamoDB.arn
}

# Generate archive
data "archive_file" "default" {
  type        = "zip"
  source_dir  = "${path.module}/functions/"
  output_path = "${path.module}/myzip/python.zip"
}

# Create Lambda function
resource "aws_lambda_function" "incrementFunction" {
  filename                       = "${path.module}/myzip/python.zip"
  function_name                  = "incrementFunction"
  role                           = aws_iam_role.lambda_role.arn
  handler                        = "index.lambda_handler"
  runtime                        = "python3.8"
  depends_on                     = [aws_iam_role_policy_attachment.policy_attach_logging, aws_iam_role_policy_attachment.policy_attach_dynamoDB]
}

resource "aws_apigatewayv2_api" "lambda" {
  name          = "serverless_lambda_gw"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "lambda" {
  api_id = aws_apigatewayv2_api.lambda.id
  name        = "serverless_lambda_stage"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "incrementFunction" {
  api_id = aws_apigatewayv2_api.lambda.id
  integration_uri    = aws_lambda_function.incrementFunction.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "incrementFunction" {
  api_id = aws_apigatewayv2_api.lambda.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.incrementFunction.id}"
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.lambda.name}"
  retention_in_days = 30
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.incrementFunction.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}
