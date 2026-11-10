output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer"
  value       = aws_lb.app.dns_name
}

output "alb_url" {
  description = "Application URL"
  value       = "http://${aws_lb.app.dns_name}"
}

output "application_health_url" {
  description = "Application health endpoint"
  value       = "http://${aws_lb.app.dns_name}/health"
}
