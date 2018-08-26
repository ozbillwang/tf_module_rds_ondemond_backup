# RDS Manual Backups

AWS Step functions calls lambda functions to perform manual backups of RDS. Cloudwatch event schedule triggers the step functions.


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

Same backup rotetion is applied to all rds instances, include cluster instances.

## How it works ##

* Step functions for DB snapshot and DB cluster snapshot will be provided as part of insfastructure by default. Based on the team's requirement, cloudwatch event schedule will be created.
* Cloudwatch event scheduler will trigger step functions.
* Step functions will call several lambda functions one by one. One to create snapshot and the other two to manage the snapshots, that is to delete the snapshots that are older than given retention period.
* As of now, daily, weekly and  monthly snapshots are supported. Allowed values in snapshot: daily, weekly, monthly.

## A real sample to use this module with terragrunt

https://github.com/ozbillwang/terragrunt_sample/config-np/ap-southeast-2/dev/rds_ondemond_backup



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

