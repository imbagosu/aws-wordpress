resource "aws_security_group" "rds" {
  name_prefix = "rds-sg-"
  vpc_id      = var.vpc_id

  ingress {
    description    = "Allow MySQL traffic from EC2 instances"
    from_port      = 3306
    to_port        = 3306
    protocol       = "tcp"
    security_groups = [var.ec2_security_group_id] # Use EC2 SG ID variable
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-security-group"
  }
}
