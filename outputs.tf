output "rds_snapshot_management_lambda_exec_role_arn" {
  value = "${aws_iam_role.snapshot_management_lambda_exec_role.arn}"
}

output "rds_snapshot_management_state_machine_exec_role_arn" {
  value = "${aws_iam_role.snapshot_management_state_machine_exec_role.arn}"
}

output "rds_create_snapshot_lambda_function_arn" {
  value = "${aws_lambda_function.create_snapshot_lambda_function.arn}"
}

output "rds_manage_rds_snapshot_lambda_function_arn" {
  value = "${aws_lambda_function.manage_snapshot_lambda_function.arn}"
}
