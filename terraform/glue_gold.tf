resource "aws_s3_object" "gold_script" {
  bucket = aws_s3_bucket.data_lake.id
  key    = "scripts/silver_to_gold.py"
  source = "./../glue/silver_to_gold.py"
  etag   = filemd5("./../glue/silver_to_gold.py")
}

resource "aws_glue_job" "silver_to_gold" {
  name     = "ecommerce-silver-to-gold"
  role_arn = aws_iam_role.glue_role.arn

  command {
    script_location = "s3://${aws_s3_bucket.data_lake.id}/scripts/silver_to_gold.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"        = "python"
    "--job-bookmark-option" = "job-bookmark-disable"
    "--SOURCE_PATH"         = "s3://${aws_s3_bucket.data_lake.id}/silver/events/"
    "--TARGET_PATH"         = "s3://${aws_s3_bucket.data_lake.id}/gold/"
    "--TempDir"             = "s3://${aws_s3_bucket.data_lake.id}/tmp/"
  }

  glue_version      = "4.0"
  number_of_workers = 2
  worker_type       = "G.1X"

  tags = {
    Project = "ecommerce-streaming"
  }
}

resource "aws_glue_crawler" "gold_crawler" {
  database_name = aws_glue_catalog_database.ecommerce_db.name
  name          = "ecommerce-gold-crawler"
  role          = aws_iam_role.glue_role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.data_lake.id}/gold/daily_sales/"
  }

  s3_target {
    path = "s3://${aws_s3_bucket.data_lake.id}/gold/product_performance/"
  }

  s3_target {
    path = "s3://${aws_s3_bucket.data_lake.id}/gold/user_engagement/"
  }

  tags = {
    Project = "ecommerce-streaming"
  }
}