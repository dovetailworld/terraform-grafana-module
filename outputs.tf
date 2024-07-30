output "efs_arn" {
  description = "Output EFS ARN"
  value       = aws_efs_file_system.this.arn
}

output "efs_id" {
  description = "Output EFS ID"
  value       = aws_efs_file_system.this.id
}

output "efs_name" {
  description = "Output EFS Name"
  value       = aws_efs_file_system.this.name
}

