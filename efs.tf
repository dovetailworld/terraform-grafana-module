# Create the EFS file system
resource "aws_efs_file_system" "this" {
  tags = {
    Name = "${var.service_name}-efs"
  }
}

# Create the EFS mount targets
resource "aws_efs_mount_target" "this" {
  count = length(var.private_subnet_ids)

  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = var.private_subnet_ids[count.index]
  security_groups = [aws_security_group.efs_sg.id]

  lifecycle {
    replace_triggered_by = [aws_security_group.efs_sg.id]
  }
}

# Create the EFS access point for the Grafana user
resource "aws_efs_access_point" "this" {
  file_system_id = aws_efs_file_system.this.id

  posix_user {
    gid = 0
    uid = 472
  }

  root_directory {

    creation_info {
      owner_gid   = 0
      owner_uid   = 472
      permissions = 0755
    }

    path = "/grafana"
  }

  tags = {
    name = "grafana-user"
  }
}
