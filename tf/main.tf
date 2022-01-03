locals {
  notes_arc_path = "../src/notes.py"
}

data "archive_file" "notes_archive" {
  type        = "zip"
  output_path = "../build/notes.zip"
  source_file = "../src/notes.py"
}

# IAM
resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = jsonencode({
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
  })
}

resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"

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

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

# LAMBDA
resource "aws_lambda_layer_version" "notes_dep_layer" {
  filename   = "../build/dep_layer.zip"
  layer_name = "notes_dep_layer"

  compatible_runtimes = ["python3.9"]
}

resource "aws_lambda_function" "notes_lambda" {
  filename      = "../build/notes.zip"
  function_name = "notes"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "notes.lambda_handler"
  layers = [aws_lambda_layer_version.notes_dep_layer.arn]

  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
  source_code_hash = data.archive_file.notes_archive.output_base64sha256

  runtime = "python3.9"

  environment {
    variables = {
      foo = "bar"
    }
  }
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notes_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.note_taker_api.execution_arn}/*/*"
}

# API GW
resource "aws_apigatewayv2_api" "note_taker_api" {
  name          = "notetaker_api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "note_taker_test" {
  api_id = aws_apigatewayv2_api.note_taker_api.id

  name        = "test"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
    })
  }
}

resource "aws_apigatewayv2_integration" "note_taker_integration" {
  api_id = aws_apigatewayv2_api.note_taker_api.id
  integration_uri    = aws_lambda_function.notes_lambda.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "note_taker_root" {
  api_id = aws_apigatewayv2_api.note_taker_api.id

  route_key = "ANY /notetaker/api/notes"
  target    = "integrations/${aws_apigatewayv2_integration.note_taker_integration.id}"
}

resource "aws_apigatewayv2_route" "note_taker_id" {
  api_id = aws_apigatewayv2_api.note_taker_api.id

  route_key = "ANY /notetaker/api/notes/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.note_taker_integration.id}"
}

# CLOUDWATCH
resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.note_taker_api.name}"

  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "notes_logs" {
  name = "/aws/lambda/${aws_lambda_function.notes_lambda.function_name}"

  retention_in_days = 30
}