# Run AWS Lambda function on local machine

## Usage

* install [python-lambda-local](https://github.com/HDE/python-lambda-local)

```
pip install python-lambda-local
```

* create event test data

```
{
  "region": "ap-southeast-2"
}
```

* run amp2aws to get aws assume role

* test locally

```
export region="ap-southeast-2"
export daily_retention="35"
export weekly_retention="12"
export monthly_retention="6"
python-lambda-local -l lib/ -f lambda_handler -t 5 ../source/create-rds-snapshot.py event.json
python-lambda-local -l lib/ -f lambda_handler -t 5 ../source/manage-rds-snapshot.py event.json
python-lambda-local -l lib/ -f lambda_handler -t 5 ../source/manage-rds-cluster-snapshot.py event.json
```
