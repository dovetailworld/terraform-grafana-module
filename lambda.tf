# Retrieve current AWS Account information
data "aws_caller_identity" "current" {}

# Create role for fargate-spot-fallback Lambda function
data "aws_iam_policy_document" "fargate_spot_fallback_assume_role" {
  count = var.enable_fallback ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "fargate_spot_fallback_role" {
  count = var.enable_fallback ? 1 : 0

  name               = "fargate-spot-fallback-role"
  description        = "Role for fargate-spot-fallback lambda function."
  assume_role_policy = data.aws_iam_policy_document.fargate_spot_fallback_assume_role[0].json
}

data "aws_iam_policy_document" "fargate_spot_fallback_policy" {
  count = var.enable_fallback ? 1 : 0

  statement {
    sid = "CreateLogGroup"

    actions   = ["logs:CreateLogGroup"]
    resources = ["arn:aws:logs:eu-west-1:${data.aws_caller_identity.current.account_id}:*"]
  }

  statement {
    sid = "CreateLogStream"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = ["arn:aws:logs:eu-west-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${aws_lambda_function.fargate_spot_fallback[0].arn}:*"]
  }

  statement {
    sid = "DescribeService"

    actions   = ["ecs:DescribeServices"]
    resources = [aws_ecs_service.fargate_spot[0].id]
  }

  statement {
    sid = "UpdateService"

    actions = [
      "ecs:DescribeServices",
      "ecs:UpdateService"
    ]

    resources = [aws_ecs_service.fargate_ondemand[0].id]
  }
}

resource "aws_iam_policy" "fargate_spot_fallback_policy" {
  count = var.enable_fallback ? 1 : 0

  name        = "fargate-spot-fallback-policy"
  description = "Policy for fargate-spot-fallback lambda function."
  policy      = data.aws_iam_policy_document.fargate_spot_fallback_policy[0].json
}

resource "aws_iam_role_policy_attachment" "fargate_spot_fallback_policy_attach" {
  count = var.enable_fallback ? 1 : 0

  role       = aws_iam_role.fargate_spot_fallback_role[0].name
  policy_arn = aws_iam_policy.fargate_spot_fallback_policy[0].arn
}

# Archive Python file
data "archive_file" "fargate_spot_fallback_lambda" {
  count = var.enable_fallback ? 1 : 0

  type        = "zip"
  source_file = "${path.module}/lambda-function/index.py"
  output_path = "${path.module}/lambda-function/lambda_function_payload.zip"
}

# Create fargate-spot-fallback Lambda function
resource "aws_lambda_function" "fargate_spot_fallback" {
  count = var.enable_fallback ? 1 : 0

  filename      = "${path.module}/lambda-function/lambda_function_payload.zip"
  function_name = "fargate-spot-fallback"
  role          = aws_iam_role.fargate_spot_fallback_role[0].arn
  handler       = "index.handler"

  source_code_hash = data.archive_file.fargate_spot_fallback_lambda[0].output_base64sha256

  runtime = "python3.8"

  environment {
    variables = {
      PRIMARY_SERVICE_ARN  = aws_ecs_service.fargate_spot[0].id
      FALLBACK_SERVICE_ARN = aws_ecs_service.fargate_ondemand[0].id
    }
  }
}
