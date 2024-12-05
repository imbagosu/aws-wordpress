data "aws_ami" "wordpress" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  owners = ["amazon"] # Owned by Amazon
}

resource "aws_launch_template" "wordpress" {
  name_prefix   = "wordpress-launch-template-"
  instance_type = "t2.micro" # Cheapest instance type
  image_id      = data.aws_ami.wordpress.id # Use AMI for WordPress

  key_name = var.key_pair_name # SSH key pair for accessing instances

  # User data script to install and configure WordPress
  user_data = <<-EOT
    #!/bin/bash
    sudo yum update -y
    sudo yum install -y httpd php php-mysqlnd
    sudo systemctl start httpd
    sudo systemctl enable httpd
    echo "<?php phpinfo(); ?>" > /var/www/html/info.php
    curl -O https://wordpress.org/latest.tar.gz
    tar -xzf latest.tar.gz
    sudo cp -r wordpress/* /var/www/html/
    sudo chown -R apache:apache /var/www/html/
    sudo systemctl restart httpd
  EOT

  # Tags for EC2 instances
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "wordpress-instance"
    }
  }
}

resource "aws_security_group" "ec2" {
  name_prefix = "ec2-sg-"
  vpc_id      = var.vpc_id

  # Inbound Rules
  ingress {
    description = "Allow HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["172.18.224.1/32"] # Open to the internet
  }

  ingress {
    description = "Allow SSH traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["172.18.224.1/32"] # Open to the internet (secure this for production)
  }

  # Outbound Rules (Allow all traffic)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-security-group"
  }
}

resource "aws_security_group" "lb" {
  name_prefix = "lb-sg-"
  vpc_id      = var.vpc_id

  # Inbound Rules
  ingress {
    description = "Allow HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Open to the internet
  }

ingress {
  description = "Allow HTTP traffic from the internet"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

  # Outbound Rules (Allow all traffic)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-security-group"
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "wordpress" {
  launch_template {
    id      = aws_launch_template.wordpress.id
    version = "$Latest"
  }

  min_size         = var.asg_min_size
  max_size         = var.asg_max_size
  desired_capacity = var.asg_desired_capacity

  vpc_zone_identifier = var.public_subnets # Use public subnets for EC2 instances

  target_group_arns = [aws_lb_target_group.wordpress.arn]

  health_check_type         = "EC2"
  health_check_grace_period = 300
  depends_on = [aws_lb_target_group.wordpress]

}

# Load Balancer for WordPress
resource "aws_lb" "wordpress" {
  name               = "wordpress-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb.id]
  subnets            = var.public_subnets

  enable_deletion_protection = false
}

# Target Group for Load Balancer
resource "aws_lb_target_group" "wordpress" {
  name     = "wordpress-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Load Balancer Listener
resource "aws_lb_listener" "wordpress" {
  load_balancer_arn = aws_lb.wordpress.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress.arn
  }
}

