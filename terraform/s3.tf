resource "aws_s3_bucket" "data_lake" {
  bucket = "ecommerce-streaming-data-lake-${random_id.suffix.hex}"

  tags = {
    Project = "ecommerce-streaming"
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}