terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.6"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

############################
# 1) WAFv2 IPSet (lista de IPs bloqueadas por la Lambda)
############################
resource "aws_wafv2_ip_set" "blocked_ips" {
  name               = "gd-autoresponse-blocked-ips"
  scope              = var.waf_scope # REGIONAL o CLOUDFRONT
  ip_address_version = "IPV4"
  addresses          = []

  tags = {
    Project = "GuardDuty-AutoResponse"
  }
}

############################
# 2) SNS para alertas
############################
resource "aws_sns_topic" "alerts" {
  name = "gd-autoresponse-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

############################
# 3) IAM para Lambda
############################
resource "aws_iam_role" "lambda_role" {
  name = "gd-autoresponse-lambda-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "lambda.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

data "aws_iam_policy_document" "lambda_policy" {
  statement {
    actions   = ["wafv2:GetIPSet", "wafv2:UpdateIPSet"]
    resources = [aws_wafv2_ip_set.blocked_ips.arn]
  }

  statement {
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alerts.arn]
  }

  statement {
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "lambda_policy" {
  name   = "gd-autoresponse-lambda-policy"
  policy = data.aws_iam_policy_document.lambda_policy.json
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

############################
# 4) Empaquetado y Lambda
############################
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda"
  output_path = "${path.module}/../lambda.zip"
}

resource "aws_lambda_function" "handler" {
  function_name = "gd-autoresponse-waf"
  role          = aws_iam_role.lambda_role.arn
  handler       = "main.handler"
  runtime       = "python3.11"
  filename      = data.archive_file.lambda_zip.output_path
  timeout       = 60

  environment {
    variables = {
      WAF_IPSET_ID  = aws_wafv2_ip_set.blocked_ips.id
      WAF_SCOPE     = var.waf_scope
      WAF_NAME      = aws_wafv2_ip_set.blocked_ips.name
      SNS_TOPIC_ARN = aws_sns_topic.alerts.arn
      BLOCK_CIDR    = var.block_cidr
    }
  }
}

############################
# (OPCIONAL) Web ACL mínimo
############################
# resource "aws_wafv2_web_acl" "gd_acl" {
#   name  = "gd-autoresponse-webacl"
#   scope = var.waf_scope
#
#   default_action { allow {} }
#
#   rule {
#     name     = "BlockBadIPs"
#     priority = 1
#     action { block {} }
#
#     statement {
#       ip_set_reference_statement { arn = aws_wafv2_ip_set.blocked_ips.arn }
#     }
#
#     visibility_config {
#       metric_name                = "BlockBadIPs"
#       cloudwatch_metrics_enabled = true
#       sampled_requests_enabled   = true
#     }
#   }
#
#   visibility_config {
#     metric_name                = "GDAutoResponseWebACL"
#     cloudwatch_metrics_enabled = true
#     sampled_requests_enabled   = true
#   }
# }
