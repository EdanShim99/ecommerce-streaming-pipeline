resource "aws_athena_workgroup" "ecommerce" {
  name = "ecommerce-streaming"

  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.data_lake.id}/athena-results/"
    }
  }

  tags = {
    Project = "ecommerce-streaming"
  }
}