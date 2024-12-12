resource "aws_db_instance" "wordpress" {
  identifier            = "wordpress-db"
  engine                = "mysql"
  engine_version        = "8.0"
  instance_class        = "db.t3.micro"
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp2"
  multi_az              = true
  username              = var.db_username
  password              = var.db_password
  db_name               = "wordpress"
  monitoring_interval   = 60 # Enables enhanced monitoring
  monitoring_role_arn   = aws_iam_role.rds_monitoring.arn
  skip_final_snapshot   = true

  tags = {
    Name = "wordpress-db"
  }
}


resource "aws_iam_role" "rds_monitoring" {
  name = "rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring_policy" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
