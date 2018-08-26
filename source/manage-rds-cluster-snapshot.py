import datetime
import boto3
import os


def lambda_handler(event, context):

    # snapshots retention
    def clean_snapshot(daily_retention, weekly_retention, monthly_retention):
        response = client.describe_db_cluster_snapshots(
            SnapshotType='manual', )

        for snapshot in response['DBClusterSnapshots']:
            deleted = False

            if snapshot['Status'] == 'available':
                snapshot_name = snapshot['DBClusterSnapshotIdentifier']
                print(snapshot_name)

                create_ts = snapshot['SnapshotCreateTime'].replace(tzinfo=None)
                if "cluster-daily" in snapshot_name:
                    reserve = daily_retention
                    deleted = True
                elif "cluster-weekly" in snapshot_name:
                    reserve = weekly_retention
                    deleted = True
                elif "cluster-monthly" in snapshot_name:
                    reserve = monthly_retention
                    deleted = True

                if deleted:
                    expiry = datetime.datetime.now() - datetime.timedelta(
                        days=reserve)
                    print("This snapshot was created at: %s" % create_ts)
                    print("Expiry date is: %s" % expiry)

                    if create_ts < expiry:
                        print("Deleting snapshot id: %s" % snapshot_name)
                        client.delete_db_cluster_snapshot(
                            DBClusterSnapshotIdentifier=snapshot_name)
                    else:
                        print("snapshot %s is not expiry" % snapshot_name)
            print

    region = os.environ['region']
    daily_retention = int(os.environ['daily_retention'])
    weekly_retention = int(os.environ['weekly_retention']) * 7
    monthly_retention = int(os.environ['monthly_retention']) * 31

    client = boto3.client('rds', region_name=region)
    clean_snapshot(daily_retention, weekly_retention, monthly_retention)
