# RDS Manual Backups

AWS Step functions calls lambda functions to perform manual backups of RDS. Cloudwatch event schedule triggers the step functions.

## Why need this feature?

If you delete RDS instance without final snapshot, all automation backups for this rds instance will be deleted. You have the risk to lost data. `Only manually created DB Snapshots are retained after the DB Instance is deleted.`

https://aws.amazon.com/rds/faqs/

>Q: What happens to my backups and DB snapshots if I delete my DB instance?

>When you delete a DB instance, you can create a final DB snapshot upon deletion; if you do, you can use this DB snapshot to restore the deleted DB instance at a later date. Amazon RDS retains this final user-created DB snapshot along with all other manually created DB snapshots after the DB instance is deleted. Refer to the pricing page for details of backup storage costs.

>Automated backups are deleted when the DB instance is deleted. Only manually created DB Snapshots are retained after the DB Instance is deleted.

## Doc generation
Documentation should be modified within `main.tf` and generated using [terraform-docs](https://github.com/segmentio/terraform-docs). Generate them like so:

    terraform-docs md . > README.md

## (optional) Install or update extra python packages.

This lambda function uses additional python packages which you need install and checkin to this repository.

    cd source; pip install -r requirements.txt  -t ./

## Test lambda function locally

Go through this README [Test lambda function locally](./test/README.md)

## Backup strategy

Two step functions. One for backing up RDS non-aurora instances and the other for aurora instance. Lambda functions are generic enough to work for any flovour of rds.

Same backup retention is applied to all rds instances, include cluster instances.

## How it works ##

* Step functions for DB snapshot and DB cluster snapshot will be provided as part of insfastructure by default. Based on the team's requirement, cloudwatch event schedule will be created.
* Cloudwatch event scheduler will trigger step functions.
* Step functions will call several lambda functions one by one. One to create snapshot and the other two to manage the snapshots, that is to delete the snapshots that are older than given retention period.
* As of now, daily, weekly and  monthly snapshots are supported. Allowed values in snapshot: daily, weekly, monthly.

## IAM policies


### Cloudwatch event rule

Trust Relationshiop
```
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
```

Permission

```
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
```

### Step functions

Trust Relationship
```
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
```

Permission
```
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
```

### Lambda functions

Trust Relationship

```
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
```

Permission
```
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
```

## aws step functions

Create a Serverless Workflow with [AWS Step Functions](https://aws.amazon.com/getting-started/tutorials/create-a-serverless-workflow-step-functions-lambda/) and AWS Lambda

* task 1: Create-RDS-Snapshot
* task 2: Delete-Old-RDS-Snapshots
* task 3: Delete-Old-RDS-Cluster-Snapshots

State machine definition

```
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
```

## A real sample to use this module with terragrunt

https://github.com/ozbillwang/terragrunt_sample/tree/master/config-np/ap-southeast-2/dev/rds_ondemond_backup



## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| aws_region |  | string | `ap-southeast-2` | no |
| backup_schedule | The scheduling expression | string | `rate(24 hours)` | no |
| daily_retention | days for retention | string | `35` | no |
| lambda_manage_rds_cluster_snapshot_lifecycle_function_name |  | string | `manage_rds_cluster_snapshot_lifecycle` | no |
| lambda_manage_rds_snapshot_lifecycle_function_name |  | string | `manage_rds_snapshot_lifecycle` | no |
| lambda_rds_cluster_snapshot_creation_function_name |  | string | `create_rds_cluster_snapshot` | no |
| lambda_rds_snapshot_creation_function_name |  | string | `create_rds_snapshot` | no |
| monthly_retention | months for retention | string | `6` | no |
| name_prefix | resource name prefix | string | `rds` | no |
| rds_ondemand_backup_path |  | string | `rds_ondemand_backup_path.zip` | no |
| weekly_retention | weeks for retention | string | `12` | no |

## Outputs

| Name | Description |
|------|-------------|
| rds_create_snapshot_lambda_function_arn |  |
| rds_manage_rds_snapshot_lambda_function_arn |  |
| rds_snapshot_management_lambda_exec_role_arn |  |
| rds_snapshot_management_state_machine_exec_role_arn |  |

