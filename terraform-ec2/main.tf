resource "aws_launch_template" "wordpress" {
  name_prefix   = "wordpress-launch-template-"
  instance_type = "t2.micro"
  image_id      = data.aws_ami.wordpress.id
  key_name      = var.key_pair_name

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ec2.id]
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_instance_profile.name
  }

  user_data = base64encode(<<-EOT
    #!/bin/bash
    set -e
    exec > >(tee /var/log/user-data.log) 2>&1

    # Update and install packages
    yum update -y
    yum install -y httpd php php-mysqlnd amazon-cloudwatch-agent wget

    # Start and enable Apache
    systemctl start httpd
    systemctl enable httpd

    # Download and configure WordPress
    cd /tmp
    wget https://wordpress.org/latest.tar.gz
    tar -xzf latest.tar.gz
    cp -r wordpress/* /var/www/html/
    
    # Set correct permissions
    chown -R apache:apache /var/www/html/
    chmod -R 755 /var/www/html/

    # Create sample WordPress config if not exists
    if [ ! -f /var/www/html/wp-config.php ]; then
      cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
    fi

    # Restart Apache to ensure all changes take effect
    systemctl restart httpd

    # CloudWatch Agent Configuration (rest of your original config remains the same)
    cat <<EOF > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
    {
      "agent": {
        "metrics_collection_interval": 60,
        "run_as_user": "root"
      },
      "logs": {
        "logs_collected": {
          "files": {
            "collect_list": [
              {
                "file_path": "/var/log/messages",
                "log_group_name": "/wordpress/ec2/messages",
                "log_stream_name": "{instance_id}"
              },
              {
                "file_path": "/var/log/httpd/access_log",
                "log_group_name": "/wordpress/ec2/httpd-access",
                "log_stream_name": "{instance_id}"
              }
            ]
          }
        }
      }
    }
    EOF
    
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s
  EOT
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "wordpress-instance"
    }
  }
}

resource "aws_autoscaling_group" "wordpress" {
  launch_template {
    id      = aws_launch_template.wordpress.id
    version = "$Latest"
  }

  min_size         = var.asg_min_size
  max_size         = var.asg_max_size
  desired_capacity = var.asg_desired_capacity

  vpc_zone_identifier = var.public_subnets

  target_group_arns = [aws_lb_target_group.wordpress.arn]

  health_check_type         = "EC2"
  health_check_grace_period = 300
  depends_on = [aws_lb_target_group.wordpress]
}

resource "aws_lb" "wordpress" {
  name               = "wordpress-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb.id]
  subnets            = var.public_subnets

  enable_deletion_protection = false
}

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

resource "aws_lb_listener" "wordpress" {
  load_balancer_arn = aws_lb.wordpress.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress.arn
  }
}

resource "aws_iam_role" "ec2_cloudwatch_role" {
  name = "ec2-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "cloudwatch_policy" {
  name        = "ec2-cloudwatch-policy"
  description = "Allow EC2 instances to send logs and metrics to CloudWatch"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups",
          "cloudwatch:PutMetricData"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_policy_attachment" {
  role       = aws_iam_role.ec2_cloudwatch_role.name
  policy_arn = aws_iam_policy.cloudwatch_policy.arn
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2-instance-profile"
  role = aws_iam_role.ec2_cloudwatch_role.name
}
