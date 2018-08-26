import pytz
import os
import datetime
import boto3


def lambda_handler(event, context):

    # create db instance snapshots (exclude db cluster instances)
    def create_instance_snapshot(db_identifier, snapshot_postfix):

        print('Loading function create_instance_snapshot')
        db_snapshot_identifier = '%s-instance-%s' % (db_identifier,
                                                     snapshot_postfix)

        response = client.describe_db_snapshots(
            DBInstanceIdentifier=db_identifier,
            DBSnapshotIdentifier=db_snapshot_identifier)

        if len(response['DBSnapshots']) == 0:

            print("RDS snapshot backups on %s stated at %s...\n" %
                  (db_identifier, now))
            print(db_snapshot_identifier)
            try:
                client.create_db_snapshot(
                    DBInstanceIdentifier=db_identifier,
                    DBSnapshotIdentifier=db_snapshot_identifier)
            except (RuntimeError, TypeError, NameError):
                print("Oops! can't create db snapshot ...")
                pass
        else:
            print("Can't create db snapshot, the snapsot %s is exist already."
                  % db_snapshot_identifier)
        print

    # create db cluster snapshots
    def create_cluster_snapshot(db_cluster, snapshot_postfix):

        print('Loading function create_cluster_snapshot')
        db_snapshot_identifier = '%s-cluster-%s' % (db_cluster,
                                                    snapshot_postfix)

        response = client.describe_db_cluster_snapshots(
            DBClusterIdentifier=db_cluster,
            DBClusterSnapshotIdentifier=db_snapshot_identifier)

        if len(response['DBClusterSnapshots']) == 0:

            print("RDS snapshot backups on %s stated at %s...\n" % (db_cluster,
                                                                    now))
            print(db_snapshot_identifier)
            try:
                client.create_db_cluster_snapshot(
                    DBClusterIdentifier=db_cluster,
                    DBClusterSnapshotIdentifier=db_snapshot_identifier)
            except (RuntimeError, TypeError, NameError):
                print("Oops! can't create db snapshot ...")
                pass
        else:
            print("Can't create db snapshot, the snapsot %s is exist already."
                  % db_snapshot_identifier)
        print

    region = os.environ['region']
    client = boto3.client('rds', region_name=region)
    now = datetime.datetime.now(pytz.timezone('Australia/Sydney'))

    # Check snapshot type: daily, weekly or monthly
    if now.strftime("%d") == "01":
        print("Create monthly snapshot for db identifiers")
        snapshot_postfix = 'monthly-%s' % (now.strftime("%Y-%m"))
    elif now.weekday() == 1:
        print("Create weekly snapshot for db identifiers")
        snapshot_postfix = 'weekly-%s-%s' % (now.strftime("%Y"),
                                             now.isocalendar()[1])
    else:
        print("Create daily snapshot for db identifiers")
        snapshot_postfix = 'daily-%s' % (now.strftime("%Y-%m-%d"))

    db_clusters = []
    response = client.describe_db_instances()
    for instance in response['DBInstances']:
        if 'DBClusterIdentifier' in instance:
            db_cluster = instance['DBClusterIdentifier']
            if db_cluster not in db_clusters:
                # create db cluster snapshots
                db_clusters.append(db_cluster)
                create_cluster_snapshot(db_cluster, snapshot_postfix)
        else:
            # create db cluster snapshots(aurora)
            db_identifier = instance['DBInstanceIdentifier']
            create_instance_snapshot(db_identifier, snapshot_postfix)

    return event

