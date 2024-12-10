
resource "aws_db_instance" "wordpress_db" {
  allocated_storage       = 20
  storage_type            = "gp2"
  engine                  = "mysql"
  engine_version          = "8.0.30"
  instance_class          = "db.t2.micro"
  db_name                 = "wordpress_db"
  username                = var.db_username
  password                = var.db_password
  publicly_accessible     = false
  multi_az                = false
  backup_retention_period = 1
  skip_final_snapshot     = true
}
