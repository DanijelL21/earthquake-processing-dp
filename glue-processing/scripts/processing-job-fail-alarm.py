import sys

import boto3
from awsglue.utils import getResolvedOptions

args = getResolvedOptions(
    sys.argv, ["JobFailedName", "Environment", "AlarmTopic"]
)
sns_client = boto3.client("sns", region_name="us-east-1")

job_name = (
    args["JobFailedName"][:60]
    if len(args["JobFailedName"]) > 60
    else args["JobFailedName"]
)
environment = args["Environment"]
topic_arn = args["AlarmTopic"]
message = f"ALARM:\n {job_name} failed in {environment}!"
subject = f"{job_name} - {environment}"

response = sns_client.publish(
    TopicArn=topic_arn, Message=message, Subject=subject
)
