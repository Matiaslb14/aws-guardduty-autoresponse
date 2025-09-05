variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_profile" {
  type    = string
  default = "mati-waf"
}

variable "alert_email" {
  type = string
}

variable "waf_scope" {
  type    = string
  default = "REGIONAL" # o "CLOUDFRONT"
}

variable "block_cidr" {
  type    = string
  default = "auto"
}
