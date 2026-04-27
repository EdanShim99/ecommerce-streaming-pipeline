resource "aws_iam_role" "step_functions_role" {
  name = "ecommerce-step-functions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Project = "ecommerce-streaming"
  }
}

resource "aws_iam_role_policy" "step_functions_policy" {
  name = "ecommerce-step-functions-policy"
  role = aws_iam_role.step_functions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "glue:StartJobRun",
          "glue:GetJobRun",
          "glue:GetJobRuns",
          "glue:BatchStopJobRun",
          "glue:StartCrawler",
          "glue:GetCrawler"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_sfn_state_machine" "etl_pipeline" {
  name     = "ecommerce-etl-pipeline"
  role_arn = aws_iam_role.step_functions_role.arn

  definition = jsonencode({
    Comment = "E-commerce ETL Pipeline: Bronze -> Silver -> Gold"
    StartAt = "BronzeToSilver"
    States = {
      BronzeToSilver = {
        Type     = "Task"
        Resource = "arn:aws:states:::glue:startJobRun.sync"
        Parameters = {
          JobName = aws_glue_job.bronze_to_silver.name
        }
        ResultPath = "$.bronzeToSilverResult"
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next        = "PipelineFailed"
            ResultPath  = "$.error"
          }
        ]
        Next = "SilverToGold"
      }

      SilverToGold = {
        Type     = "Task"
        Resource = "arn:aws:states:::glue:startJobRun.sync"
        Parameters = {
          JobName = aws_glue_job.silver_to_gold.name
        }
        ResultPath = "$.silverToGoldResult"
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next        = "PipelineFailed"
            ResultPath  = "$.error"
          }
        ]
        Next = "RunGoldCrawler"
      }

      RunGoldCrawler = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:glue:startCrawler"
        Parameters = {
          Name = "ecommerce-gold-crawler"
        }
        ResultPath = "$.crawlerResult"
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next        = "PipelineFailed"
            ResultPath  = "$.error"
          }
        ]
        Next = "WaitForCrawler"
      }

      WaitForCrawler = {
        Type    = "Wait"
        Seconds = 30
        Next    = "CheckCrawler"
      }

      CheckCrawler = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:glue:getCrawler"
        Parameters = {
          Name = "ecommerce-gold-crawler"
        }
        ResultPath = "$.crawlerStatus"
        Next       = "IsCrawlerDone"
      }

      IsCrawlerDone = {
        Type = "Choice"
        Choices = [
          {
            Variable     = "$.crawlerStatus.Crawler.State"
            StringEquals = "READY"
            Next         = "PipelineSucceeded"
          }
        ]
        Default = "WaitForCrawler"
      }

      PipelineSucceeded = {
        Type     = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          TopicArn = aws_sns_topic.pipeline_alerts.arn
          Message  = "E-commerce ETL pipeline completed successfully!"
          Subject  = "Pipeline Success"
        }
        End = true
      }

      PipelineFailed = {
        Type     = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          TopicArn    = aws_sns_topic.pipeline_alerts.arn
          "Message.$" = "States.Format('Pipeline failed: {}', $.error.Cause)"
          Subject     = "Pipeline Failure"
        }
        Next = "FailState"
      }

      FailState = {
        Type  = "Fail"
        Error = "PipelineFailed"
        Cause = "ETL pipeline encountered an error"
      }
    }
  })

  tags = {
    Project = "ecommerce-streaming"
  }
}