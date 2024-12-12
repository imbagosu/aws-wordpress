resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name                = "HighCPUUtilization"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 2
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = 300
  statistic                 = "Average"
  threshold                 = 80
  alarm_description         = "This alarm triggers if CPU utilization exceeds 80%."
  dimensions = {
    InstanceId = aws_instance.wordpress.id
  }
  actions_enabled           = true
  alarm_actions             = [aws_autoscaling_policy.scale_up.arn]
}
