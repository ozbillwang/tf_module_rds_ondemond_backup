variable "aws_region" {
  default = "ap-southeast-2"
}

variable "name_prefix" {
  description = "resource name prefix"
  default     = "rds"
}

variable "rds_ondemand_backup_path" {
  default = "rds_ondemand_backup_path.zip"
}

variable "lambda_rds_snapshot_creation_function_name" {
  default = "create_rds_snapshot"
}

variable "lambda_manage_rds_snapshot_lifecycle_function_name" {
  default = "manage_rds_snapshot_lifecycle"
}

variable "lambda_rds_cluster_snapshot_creation_function_name" {
  default = "create_rds_cluster_snapshot"
}

variable "lambda_manage_rds_cluster_snapshot_lifecycle_function_name" {
  default = "manage_rds_cluster_snapshot_lifecycle"
}

variable "backup_schedule" {
  description = "The scheduling expression"
  default     = "rate(24 hours)"
}

variable "daily_retention" {
  description = "days for retention"
  default     = "35"
}

variable "weekly_retention" {
  description = "weeks for retention"
  default     = "12"
}

variable "monthly_retention" {
  description = "months for retention"
  default     = "6"
}
