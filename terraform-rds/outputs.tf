output "db_endpoint" {
  description = "RDS endpoint for the database"
  value       = aws_db_instance.wordpress.endpoint
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.wordpress.db_name
}
