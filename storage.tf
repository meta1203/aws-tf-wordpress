resource "aws_efs_file_system" "wp_storage" {
  creation_token = "wordpress-${random_string.install.id}"

  lifecycle {
    ignore_changes = [size_in_bytes]
  }
}

resource "aws_efs_backup_policy" "wp_storage_backup" {
  file_system_id = aws_efs_file_system.wp_storage.id
  backup_policy {
    status = "ENABLED"
  }
}

resource "aws_efs_mount_target" "alpha" {
  count = length(aws_subnet.sn)
  
  file_system_id  = aws_efs_file_system.wp_storage.id
  subnet_id       = aws_subnet.sn[count.index].id
  security_groups = [aws_security_group.sg.id]
}

resource "aws_cloudwatch_log_group" "wp_log" {
  name = "wordpress-${random_string.install.id}-task"
}

resource "aws_rds_cluster" "wp_db" {
  cluster_identifier      = "wordpress-${random_string.install.id}"
  engine                  = "aurora-mysql"
  engine_version          = "5.7.mysql_aurora.2.07.1"
  engine_mode             = "serverless"
  database_name           = "wordpress${random_string.install.id}"
  master_username         = "king_wp"
  master_password         = random_string.pw.id
  
  backup_retention_period = 5
  preferred_backup_window = "07:00-09:00"
  skip_final_snapshot = true
  
  db_subnet_group_name    = aws_db_subnet_group.default.name
  vpc_security_group_ids  = [aws_security_group.sg.id]
}

resource "aws_db_subnet_group" "default" {
  name       = "wordpress-${random_string.install.id}"
  subnet_ids = aws_subnet.sn.*.id

  tags = {
    Name = "wordpress-${random_string.install.id}"
  }
}
