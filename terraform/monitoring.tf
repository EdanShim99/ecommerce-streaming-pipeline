resource "aws_sns_topic" "pipeline_alerts" {
  name = "ecommerce-pipeline-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.pipeline_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "sfn_failures" {
  alarm_name          = "ecommerce-pipeline-failures"
  alarm_description   = "Triggers when the ETL pipeline state machine fails"
  namespace           = "AWS/States"
  metric_name         = "ExecutionsFailed"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    StateMachineArn = aws_sfn_state_machine.etl_pipeline.arn
  }

  alarm_actions = [aws_sns_topic.pipeline_alerts.arn]
}