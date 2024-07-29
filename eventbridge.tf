resource "aws_cloudwatch_event_rule" "this" {
  name        = "ecs-service-action"
  description = "Capture ECS Service Actions"

  event_pattern = jsonencode({
    source      = ["aws.ecs"],
    detail-type = ["ECS Service Action"],
    resources   = ["arn:aws:ecs:eu-west-1:609188321737:service/grafana/grafana-spot"],
    detail = {
      "eventName" : ["SERVICE_STEADY_STATE", "SERVICE_TASK_PLACEMENT_FAILURE"]
    }
  })
}

resource "aws_cloudwatch_event_target" "this" {
  arn  = aws_lambda_function.fargate_spot_fallback.id
  rule = aws_cloudwatch_event_rule.this.id
}
