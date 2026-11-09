
resource "aws_cloudwatch_metric_alarm" "app_cpu_high" {
  alarm_name        = "${var.project_name}-high-cpu"
  alarm_description = "Alert when application EC2 CPU is high"

  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }
}
