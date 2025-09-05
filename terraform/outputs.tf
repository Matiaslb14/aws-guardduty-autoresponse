output "waf_ipset_name" {
  value = aws_wafv2_ip_set.blocked_ips.name
}

output "waf_ipset_id" {
  value = aws_wafv2_ip_set.blocked_ips.id
}

output "waf_ipset_arn" {
  value = aws_wafv2_ip_set.blocked_ips.arn
}

output "sns_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

output "lambda_name" {
  value = aws_lambda_function.handler.function_name
}
