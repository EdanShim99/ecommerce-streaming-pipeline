variable "region" {
  default = "us-west-1"
}

variable "stream_name" {
  default = "ecommerce-events-stream"
}

variable "alert_email" {
  description = "Email address for pipeline failure alerts"
  type        = string
}