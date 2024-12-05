output "load_balancer_dns" {
  description = "DNS of the load balancer"
  value       = aws_lb.wordpress.dns_name
}

output "ec2_security_group_id" {
  description = "ID of the EC2 Security Group"
  value       = aws_security_group.ec2.id
}
