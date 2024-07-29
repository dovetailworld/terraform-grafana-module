data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "fargate_spot_fallback_assume_role" {
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
  name               = "Role for Fargate Spot Fallback Lambda function."
  assume_role_policy = data.aws_iam_policy_document.fargate_spot_fallback_assume_role.json
}

data "aws_iam_policy_document" "fargate_spot_fallback_policy" {
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

    resources = ["arn:aws:logs:eu-west-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${aws_lambda_function.this}:*"]
  }

  statement {
    sid = "DescribeService"

    actions   = ["ecs:DescribeServices"]
    resources = [aws_ecs_service.fargate_spot.arn]
  }

  statement {
    sid = "UpdateService"

    actions = [
      "ecs:DescribeServices",
      "ecs:UpdateService"
    ]

    resources = [aws_ecs_service.fargate.arn]
  }
}

resource "aws_iam_policy" "fargate_spot_fallback_policy" {
  name        = "fargate-spot-fallback-policy"
  description = "A test policy"
  policy      = data.aws_iam_policy_document.fargate_spot_fallback_policy.json
}

resource "aws_iam_role_policy_attachment" "fargate_spot_fallback_policy_attach" {
  role       = aws_iam_role.fargate_spot_fallback_role.name
  policy_arn = aws_iam_policy.fargate_spot_fallback_policy.arn
}

data "archive_file" "fargate_spot_fallback_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda-function/index.py"
  output_path = "${path.module}/lambda-function/lambda_function_payload.zip"
}

resource "aws_lambda_function" "fargate_spot_fallback" {
  filename      = "${path.module}/lambda-function/lambda_function_payload.zip"
  function_name = "fargate-spot-fallback"
  role          = aws_iam_role.fargate_spot_fallback_role.arn
  handler       = "index.test"

  source_code_hash = data.archive_file.fargate_spot_fallback_lambda.output_base64sha256

  runtime = "python3.8"

  environment {
    variables = {
      PRIMARY_SERVICE_ARN  = aws_ecs_service.fargate_spot.arn
      FALLBACK_SERVICE_ARN = aws_ecs_service.fargate.arn
    }
  }
}
