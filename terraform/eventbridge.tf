resource "aws_cloudwatch_event_rule" "pipeline_schedule" {
  name                = "ecommerce-pipeline-schedule"
  description         = "Triggers the ecommerce data pipeline hourly"
  schedule_expression = "rate(1 hour)"
  state               = "DISABLED"
}

resource "aws_cloudwatch_event_target" "step_function" {
  rule     = aws_cloudwatch_event_rule.pipeline_schedule.name
  arn      = aws_sfn_state_machine.etl_pipeline.arn
  role_arn = aws_iam_role.eventbridge_role.arn
}

resource "aws_iam_role" "eventbridge_role" {
  name = "ecommerce-eventbridge-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "eventbridge_sfn" {
  name = "eventbridge-start-sfn"
  role = aws_iam_role.eventbridge_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "states:StartExecution"
        Resource = aws_sfn_state_machine.etl_pipeline.arn
      }
    ]
  })
}