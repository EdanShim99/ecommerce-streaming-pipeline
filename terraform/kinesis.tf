resource "aws_kinesis_stream" "ecommerce_events" {
  name             = var.stream_name
  shard_count      = 1
  retention_period = 24

  tags = {
    Project = "ecommerce-streaming"
  }
}