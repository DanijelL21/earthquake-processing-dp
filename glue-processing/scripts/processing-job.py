import json
import sys

import boto3
from awsglue.context import GlueContext
from awsglue.dynamicframe import DynamicFrame
from awsglue.job import Job
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from botocore.exceptions import ClientError
from pyspark.context import SparkContext

args = getResolvedOptions(
    sys.argv,
    [
        "JobName",
        "SourceDatabaseName",
        "SourceTableName",
        "DestTableName",
        "SecretName",
        "SFDatabase",
        "SFSchema",
    ],
)

source_database = args["SourceDatabaseName"]
source_table = args["SourceTableName"]
dest_table = args["DestTableName"]
secret_name = args["SecretName"]
sfDatabase = args["SFDatabase"]
sfSchema = args["SecretName"]

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)

job.init(args["JobName"], args)


def get_secret(secret_name, region="us-east-1"):
    session = boto3.session.Session()
    client = session.client(service_name="secretsmanager", region_name=region)

    try:
        get_secret_value_response = client.get_secret_value(
            SecretId=secret_name
        )
    except ClientError as e:
        raise e

    secret = get_secret_value_response["SecretString"]
    return json.loads(secret)


try:

    earthquake_datasource_dyf = glueContext.create_dynamic_frame.from_catalog(
        database=source_database,
        table_name=source_table,
        transformation_ctx="earthquake_data",
    )

    if earthquake_datasource_dyf.count() > 0:
        earthquake_df = earthquake_datasource_dyf.toDF()

        earthquake_df.createOrReplaceTempView("events")
        query = """
        SELECT
        DISTINCT *, 
        cast(CONCAT(partition_0,partition_1,partition_2) as int) as ingest_date 
        from events
        """

        filtered_earthquake_df = spark.sql(query).drop(
            "partition_0", "partition_1", "partition_2", "partition_3"
        )

        print(f"Table count: {filtered_earthquake_df.count()}")

        dyf = DynamicFrame.fromDF(filtered_earthquake_df, glueContext, "dyf")

        secret_config = get_secret(secret_name)

        glueContext.write_dynamic_frame.from_options(
            frame=dyf,
            connection_type="snowflake",
            connection_options={
                "sfurl": secret_config["sfurl"],
                "dbtable": dest_table,
                "sfuser": secret_config["sfuser"],
                "sfpassword": secret_config["sfpassword"],
                "sfDatabase": sfDatabase,
                "sfSchema": sfSchema,
                "sfWarehouse": "COMPUTE_WH",
                "preactions": f"TRUNCATE TABLE {dest_table}",
            },
        )

    else:
        print("No new records.")

except Exception as e:
    print(f"Something went wrong. {e}")
    raise e

job.commit()
