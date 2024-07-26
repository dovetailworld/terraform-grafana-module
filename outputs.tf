output "efs_arn" {
  value = aws_efs_file_system.this.arn
}

output "efs_id" {
  value = aws_efs_file_system.this.id
}

output "efs_name" {
  value = aws_efs_file_system.this.name
}
