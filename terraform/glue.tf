resource "aws_iam_role" "glue_role" {
  name = "ecommerce-glue-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "glue.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "glue_policy" {
  name = "ecommerce-glue-policy"
  role = aws_iam_role.glue_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.data_lake.arn,
          "${aws_s3_bucket.data_lake.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "glue:*"
        ]
        Resource = ["*"]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = ["*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# ──────────────────────────────────────────────
# Glue Catalog Database
# ──────────────────────────────────────────────

resource "aws_glue_catalog_database" "ecommerce_db" {
  name = "ecommerce_streaming_db"
}

# ──────────────────────────────────────────────
# Bronze Layer
# ──────────────────────────────────────────────

resource "aws_glue_crawler" "bronze_crawler" {
  database_name = aws_glue_catalog_database.ecommerce_db.name
  name          = "ecommerce-bronze-crawler"
  role          = aws_iam_role.glue_role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.data_lake.id}/bronze/raw-events/"
  }

  tags = {
    Project = "ecommerce-streaming"
  }
}

resource "aws_s3_object" "glue_script" {
  bucket = aws_s3_bucket.data_lake.id
  key    = "scripts/bronze_to_silver.py"
  source = "${path.module}/../glue/bronze_to_silver.py"
  etag   = filemd5("${path.module}/../glue/bronze_to_silver.py")
}

resource "aws_glue_job" "bronze_to_silver" {
  name     = "ecommerce-bronze-to-silver"
  role_arn = aws_iam_role.glue_role.arn

  command {
    script_location = "s3://${aws_s3_bucket.data_lake.id}/scripts/bronze_to_silver.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"        = "python"
    "--SOURCE_PATH"         = "s3://${aws_s3_bucket.data_lake.id}/bronze/raw-events/"
    "--TARGET_PATH"         = "s3://${aws_s3_bucket.data_lake.id}/silver/events/"
    "--TempDir"             = "s3://${aws_s3_bucket.data_lake.id}/tmp/"
    "--job-bookmark-option" = "job-bookmark-enable"
  }

  glue_version      = "4.0"
  number_of_workers = 2
  worker_type       = "G.1X"

  tags = {
    Project = "ecommerce-streaming"
  }
}

# ──────────────────────────────────────────────
# Silver Layer
# ──────────────────────────────────────────────

resource "aws_glue_crawler" "silver_crawler" {
  database_name = aws_glue_catalog_database.ecommerce_db.name
  name          = "ecommerce-silver-crawler"
  role          = aws_iam_role.glue_role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.data_lake.id}/silver/events/"
  }

  tags = {
    Project = "ecommerce-streaming"
  }
}

resource "aws_s3_object" "gold_script" {
  bucket = aws_s3_bucket.data_lake.id
  key    = "scripts/silver_to_gold.py"
  source = "${path.module}/../glue/silver_to_gold.py"
  etag   = filemd5("${path.module}/../glue/silver_to_gold.py")
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

# ──────────────────────────────────────────────
# Gold Layer
# ──────────────────────────────────────────────

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