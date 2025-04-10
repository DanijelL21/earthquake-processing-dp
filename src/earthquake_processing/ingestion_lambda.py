"""
This lambda will fetch earthquake_data from API, process it and send to kinesis firehose stream
"""

import json
import os

from aws_lambda_powertools import Logger

from earthquake_processing.common import FirehoseDelivery, get_earthquake_data

logger = Logger()

api_url = os.environ.get("API_URL")
delivery_stream = os.environ.get("DELIVERY_STREAM")


def lambda_handler(event, context):
    firehose_delivery = FirehoseDelivery(
        delivery_stream=delivery_stream,
    )

    earthquake_data = get_earthquake_data(api_url)

    firehose_delivery.deliver_records(earthquake_data.parse_earthquake_data())

    logger.info(f"Total records submitted to s3: {firehose_delivery.status}")
