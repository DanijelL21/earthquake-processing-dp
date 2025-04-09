import json
import time
from dataclasses import dataclass, field
from typing import Any, Dict, Iterator, List

import boto3
import requests
from aws_lambda_powertools import Logger
from tenacity import (
    retry,
    retry_if_exception_type,
    stop_after_attempt,
    wait_exponential,
)

from earthquake_processing.schemas import EarthquakeData, EarthquakeGeoJSON

logger = Logger()


@retry(
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=1, min=2, max=30),
    retry=retry_if_exception_type(Exception),
)
def get_earthquake_data(api_url: str, hours: int = 1) -> EarthquakeGeoJSON:
    """
    Fetch earthquake data from the API in GeoJSON format.

    Parameters
    ----------
    api_url
        base URL of the earthquake API
    hours
        number of past hours to retrieve earthquake data for

    Returns
    -------
    EarthquakeGeoJSON
        parsed earthquake data in GeoJSON format
    """
    url = (
        f"{api_url}/query?format=geojson&starttime=NOW-{hours}hour&endtime=NOW"
    )
    response = requests.get(url)

    if response.status_code == 200:
        return EarthquakeGeoJSON.parse_obj(response.json())
    else:
        logger.error(
            f"Failed to fetch data. Status code: {response.status_code}"
        )
        response.raise_for_status()


@dataclass
class Status:
    """
    Just counting successfully processed records and maps

    Attributes
    ----------
    successful_records
        how many records are successfully written to firehose
    """

    successful_records: int = 0

    def update_records(self) -> None:
        """Increase number of successful records by 1"""

        self.successful_records += 1


@dataclass
class FirehoseDelivery:
    """
    Responsible for writing data to firehose.

    Attributes
    ----------
    delivery_stream
        firehose name where to put data
    firehose_client
        boto3 firehose client
    status
        status of totally processed records
    """

    delivery_stream: str
    region: str = "us-east-1"
    firehose_client: Any = None
    batch_records: List[Dict[str, bytes]] = field(default_factory=list)
    data_size: int = 0
    status: Status = field(default_factory=Status)

    def __post_init__(self):
        """If we haven't got firehose_client then set the default one."""

        if self.firehose_client is None:
            self.firehose_client = boto3.client(
                "firehose", region_name=self.region
            )

    def deliver_records(
        self, earthquake_data: Iterator[EarthquakeData]
    ) -> None:
        """
        Writing records to firehose and updating status.

        Parameters
        ----------
        earthquake_data
            holds data to write to firehose
        """
        batch_size_limit = 4000000
        batch_count_limit = 500

        for record in earthquake_data:
            data_blob = (json.dumps(record.dict()) + "\n").encode("UTF-8")
            data_blob_size = len(data_blob)

            if (
                len(self.batch_records) + 1 >= batch_count_limit - 1
                or (self.data_size + data_blob_size) > batch_size_limit
            ):
                self.send_batch_to_stream()

            self.data_size += data_blob_size
            self.batch_records.append({"Data": data_blob})
            self.status.update_records()

        self.send_batch_to_stream()

    def send_batch_to_stream(self):
        """
        If we have some records in batch, then write'em to firehose and
        empty batch.
        """
        records_to_deliver = self.batch_records

        if len(records_to_deliver) > 0:
            write_response = self.write_to_stream(records_to_deliver)

            if write_response["FailedPutCount"] > 0:
                for i in range(5):
                    failed_records_indices = [
                        index
                        for index, record in enumerate(
                            write_response["RequestResponses"]
                        )
                        if record.get("ErrorCode", None)
                    ]
                    records_to_deliver = [
                        record
                        for index, record in enumerate(records_to_deliver)
                        if index in failed_records_indices
                    ]
                    write_response = self.write_to_stream(records_to_deliver)
                    if write_response["FailedPutCount"] == 0:
                        break
                    else:
                        time.sleep(2**i)
                else:
                    raise Exception(
                        f"Couldn't write everything to Firehose. {write_response}"
                    )

            self.batch_records = []
            self.data_size = 0

    def write_to_stream(self, records: List[Dict[str, bytes]]) -> dict:
        """
        Write to firehose.

        Parameters
        ----------
        records
            list of records to send to firehose

        Returns
        -------
        dict
            firehose_client put_record_batch response
        """

        write_response = self.firehose_client.put_record_batch(
            DeliveryStreamName=self.delivery_stream,
            Records=records,
        )

        return write_response
