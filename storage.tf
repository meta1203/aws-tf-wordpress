resource "aws_efs_file_system" "wp_storage" {
  creation_token = "wordpress-${random_string.install.id}"
}

resource "aws_efs_backup_policy" "wp_storage_backup" {
  file_system_id = aws_efs_file_system.wp_storage.id
  backup_policy {
    status = "ENABLED"
  }
}
