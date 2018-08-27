/** 
 * # RDS Manual Backups

 * AWS Step functions calls lambda functions to perform manual backups of RDS. Cloudwatch event schedule triggers the step functions.
 *
 *
 * ## Doc generation
 * Documentation should be modified within `main.tf` and generated using [terraform-docs](https://github.com/segmentio/terraform-docs). Generate them like so:
 * 
 *     terraform-docs md . > README.md
 *
 * ## (optional) Install or update extra python packages.
 *
 * This lambda function uses additional python packages which you need install and checkin to this repository.
 *
 *     cd source; pip install -r requirements.txt  -t ./
 *
 * ## Test lambda function locally
 *
 * Go through this README [Test lambda function locally](./test/README.md)
 *
 * ## Backup strategy
 *
 * Two step functions. One for backing up RDS non-aurora instances and the other for aurora instance. Lambda functions are generic enough to work for any flovour of rds.
 *
 * Same backup retention is applied to all rds instances, include cluster instances.
 *
 * ## How it works ##
 *
 * * Step functions for DB snapshot and DB cluster snapshot will be provided as part of insfastructure by default. Based on the team's requirement, cloudwatch event schedule will be created.
 * * Cloudwatch event scheduler will trigger step functions.
 * * Step functions will call several lambda functions one by one. One to create snapshot and the other two to manage the snapshots, that is to delete the snapshots that are older than given retention period.
 * * As of now, daily, weekly and  monthly snapshots are supported. Allowed values in snapshot: daily, weekly, monthly.
 *
 * ## IAM policies
 *
 *
 * ### Cloudwatch event rule
 *
 * Trust Relationshiop
 * ```
 * {
 *   "Version": "2012-10-17",
 *   "Statement": [
 *     {
 *       "Sid": "",
 *       "Effect": "Allow",
 *       "Principal": {
 *         "Service": "events.amazonaws.com"
 *       },
 *       "Action": "sts:AssumeRole"
 *     }
 *   ]
 * }
 * ```
 *
 * Permission
 *
 * ```
 * {
 *     "Version": "2012-10-17",
 *     "Statement": [
 *         {
 *             "Sid": "CloudWatchEventsInvocationAccess",
 *             "Effect": "Allow",
 *             "Action": [
 *                 "states:StartExecution"
 *             ],
 *             "Resource": "*"
 *         }
 *     ]
 * }
 * ```
 *
 * ### Step functions
 *
 * Trust Relationship
 * ```
 * {
 *   "Version": "2012-10-17",
 *   "Statement": [
 *     {
 *       "Effect": "Allow",
 *       "Principal": {
 *         "Service": "states.amazonaws.com"
 *       },
 *       "Action": "sts:AssumeRole"
 *     }
 *   ]
 * }
 * ```
 *
 * Permission
 * ```
 * {
 *     "Version": "2012-10-17",
 *     "Statement": [
 *         {
 *             "Sid": "",
 *             "Effect": "Allow",
 *             "Action": [
 *                 "lambda:InvokeFunction"
 *             ],
 *             "Resource": [
 *                 "*"
 *             ]
 *         }
 *     ]
 * }
 * ```
 *
 * ### Lambda functions
 *
 * Trust Relationship
 *
 * ```
 * {
 *   "Version": "2012-10-17",
 *   "Statement": [
 *     {
 *       "Effect": "Allow",
 *       "Principal": {
 *         "Service": "lambda.amazonaws.com"
 *       },
 *       "Action": "sts:AssumeRole"
 *     }
 *   ]
 * }
 * ```
 *
 * Permission
 * ```
 * {
 *     "Version": "2012-10-17",
 *     "Statement": [
 *         {
 *             "Sid": "",
 *             "Effect": "Allow",
 *             "Action": [
 *                 "rds:AddTagsToResource",
 *                 "rds:CopyDBSnapshot",
 *                 "rds:CopyDBClusterSnapshot",
 *                 "rds:DeleteDBSnapshot",
 *                 "rds:CreateDBSnapshot",
 *                 "rds:CreateDBClusterSnapshot",
 *                 "rds:ModifyDBClusterSnapshotAttribute",
 *                 "rds:ModifyDBSnapshotAttribute",
 *                 "rds:RestoreDBInstanceFromDBSnapshot",
 *                 "rds:Describe*",
 *                 "rds:ListTagsForResource",
 *                 "logs:CreateLogGroup",
 *                 "logs:CreateLogStream",
 *                 "logs:PutLogEvents"
 *             ],
 *             "Resource": [
 *                 "*"
 *             ]
 *         }
 *     ]
 * }
 * ```
 *
 * ## aws step functions
 *
 * Create a Serverless Workflow with [AWS Step Functions](https://aws.amazon.com/getting-started/tutorials/create-a-serverless-workflow-step-functions-lambda/) and AWS Lambda
 *
 * * task 1: Create-RDS-Snapshot
 * * task 2: Delete-Old-RDS-Snapshots
 * * task 3: Delete-Old-RDS-Cluster-Snapshots
 *
 * State machine definition
 *
 * ```
 * {
 *   "Comment": "Manages lifecycle of rds snapshots.",
 *   "StartAt": "Create-RDS-Snapshot",
 *   "States": {
 *     "Create-RDS-Snapshot": {
 *       "Type": "Task",
 *       "Resource": "${aws_lambda_function.create_snapshot_lambda_function.arn}",
 *       "Next": "Delete-Old-RDS-Snapshots"
 *     },
 *     "Delete-Old-RDS-Snapshots": {
 *       "Type": "Task",
 *       "Resource": "${aws_lambda_function.manage_snapshot_lambda_function.arn}",
 *       "Next": "Delete-Old-RDS-Cluster-Snapshots"
 *     },
 *     "Delete-Old-RDS-Cluster-Snapshots": {
 *       "Type": "Task",
 *       "Resource": "${aws_lambda_function.manage_cluster_snapshot_lambda_function.arn}",
 *       "End": true
 *     }
 *   }
 *  }
 * ```
 *
 * ## A real sample to use this module with terragrunt
 *
 * https://github.com/ozbillwang/terragrunt_sample/config-np/ap-southeast-2/dev/rds_ondemond_backup
 * 
 */

# Lambda Exec Role
resource "aws_iam_role" "snapshot_management_lambda_exec_role" {
  name = "${var.name_prefix}_snapshot_management_lambda_exec_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# State Machine Exec Role
resource "aws_iam_role" "snapshot_management_state_machine_exec_role" {
  name = "${var.name_prefix}_snapshot_management_state_machine_exec_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "states.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Cloudwatch Events Role
resource "aws_iam_role" "snapshot_management_cloudwatch_events_role" {
  name = "${var.name_prefix}_snapshot_management_cloudwatch_events_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "events.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "snapshot_management_cloudwatch_events_role_policy" {
  name = "${var.name_prefix}_snapshot_management_cloudwatch_events_role_policy"
  role = "${aws_iam_role.snapshot_management_cloudwatch_events_role.id}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "CloudWatchEventsInvocationAccess",
            "Effect": "Allow",
            "Action": [
                "states:StartExecution"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "snapshot_management_state_machine_exec_role_policy" {
  name = "${var.name_prefix}_snapshot_management_state_machine_exec_role_policy"
  role = "${aws_iam_role.snapshot_management_state_machine_exec_role.id}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "lambda:InvokeFunction"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "snapshot_management_lambda_exec_role_policy" {
  name = "${var.name_prefix}_snapshot_management_lambda_exec_role_policy"
  role = "${aws_iam_role.snapshot_management_lambda_exec_role.id}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "rds:AddTagsToResource",
                "rds:CopyDBSnapshot",
                "rds:CopyDBClusterSnapshot",
                "rds:DeleteDBSnapshot",
                "rds:CreateDBSnapshot",
                "rds:CreateDBClusterSnapshot",
                "rds:ModifyDBClusterSnapshotAttribute",
                "rds:ModifyDBSnapshotAttribute",
                "rds:RestoreDBInstanceFromDBSnapshot",
                "rds:Describe*",
                "rds:ListTagsForResource",
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}
EOF
}

# Compress source dir
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "source"
  output_path = "${var.rds_ondemand_backup_path}"
}

# Create rds snapshot
resource "aws_lambda_function" "create_snapshot_lambda_function" {
  description   = "Lambda to create rds manual snapshot. This lambda will be called by state machine"
  filename      = "${var.rds_ondemand_backup_path}"
  function_name = "${var.name_prefix}_${var.lambda_rds_snapshot_creation_function_name}"
  role          = "${aws_iam_role.snapshot_management_lambda_exec_role.arn}"
  handler       = "create-rds-snapshot.lambda_handler"

  source_code_hash = "${data.archive_file.lambda_zip.output_base64sha256}"
  runtime          = "python3.6"
  timeout          = 300

  environment {
    variables = {
      region = "${var.aws_region}"
    }
  }
}

# manage rds snapshot lifecycle
resource "aws_lambda_function" "manage_snapshot_lambda_function" {
  description   = "Lambda to manage rds manual snapshot lifecycle. Delete snapshots that are older than retention retentionPeriod"
  filename      = "${var.rds_ondemand_backup_path}"
  function_name = "${var.name_prefix}_${var.lambda_manage_rds_snapshot_lifecycle_function_name}"
  role          = "${aws_iam_role.snapshot_management_lambda_exec_role.arn}"
  handler       = "manage-rds-snapshot.lambda_handler"

  source_code_hash = "${data.archive_file.lambda_zip.output_base64sha256}"
  runtime          = "python3.6"
  timeout          = 300

  environment {
    variables = {
      region            = "${var.aws_region}"
      daily_retention   = "${var.daily_retention}"
      weekly_retention  = "${var.weekly_retention}"
      monthly_retention = "${var.monthly_retention}"
    }
  }
}

# manage rds cluster snapshot lifecycle
resource "aws_lambda_function" "manage_cluster_snapshot_lambda_function" {
  description   = "Lambda to manage rds manual cluster snapshot lifecycle. Delete cluster snapshots that are older than retention retentionPeriod"
  filename      = "${var.rds_ondemand_backup_path}"
  function_name = "${var.name_prefix}_${var.lambda_manage_rds_cluster_snapshot_lifecycle_function_name}"
  role          = "${aws_iam_role.snapshot_management_lambda_exec_role.arn}"
  handler       = "manage-rds-cluster-snapshot.lambda_handler"

  source_code_hash = "${data.archive_file.lambda_zip.output_base64sha256}"
  runtime          = "python3.6"
  timeout          = 300

  environment {
    variables = {
      region            = "${var.aws_region}"
      daily_retention   = "${var.daily_retention}"
      weekly_retention  = "${var.weekly_retention}"
      monthly_retention = "${var.monthly_retention}"
    }
  }
}

# State machine to manage rds snapshot
resource "aws_sfn_state_machine" "snapshot_management_state_machine" {
  name     = "${var.name_prefix}_rds-snapshot-management-state-machine"
  role_arn = "${aws_iam_role.snapshot_management_state_machine_exec_role.arn}"

  definition = <<EOF
{
  "Comment": "Manages lifecycle of rds snapshots.",
  "StartAt": "Create-RDS-Snapshot",
  "States": {
    "Create-RDS-Snapshot": {
      "Type": "Task",
      "Resource": "${aws_lambda_function.create_snapshot_lambda_function.arn}",
      "Next": "Delete-Old-RDS-Snapshots"
    },
    "Delete-Old-RDS-Snapshots": {
      "Type": "Task",
      "Resource": "${aws_lambda_function.manage_snapshot_lambda_function.arn}",
      "Next": "Delete-Old-RDS-Cluster-Snapshots"
    },
    "Delete-Old-RDS-Cluster-Snapshots": {
      "Type": "Task",
      "Resource": "${aws_lambda_function.manage_cluster_snapshot_lambda_function.arn}",
      "End": true
    }
  }
 }
EOF
}

# Cloudwatch event rule that listens for table create & table delete
resource "aws_cloudwatch_event_rule" "backup_cw_event_listener" {
  name                = "${var.name_prefix}_backup_cw_event_listener"
  description         = "CloudWatch Events Rule to React to create rds snapshot events"
  role_arn            = "${aws_iam_role.snapshot_management_cloudwatch_events_role.arn}"
  schedule_expression = "${var.backup_schedule}"
}

# Cloudwatch table listener target
resource "aws_cloudwatch_event_target" "backup_cw_event_target" {
  target_id = "${var.name_prefix}_backup_cw_event_target"
  rule      = "${aws_cloudwatch_event_rule.backup_cw_event_listener.name}"
  arn       = "${aws_sfn_state_machine.snapshot_management_state_machine.id}"
  role_arn  = "${aws_iam_role.snapshot_management_cloudwatch_events_role.arn}"
}

# Give Cloudwatch events permission to call the backup function
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.create_snapshot_lambda_function.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.backup_cw_event_listener.arn}"
}
