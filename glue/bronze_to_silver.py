import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.dynamicframe import DynamicFrame
from pyspark.sql.functions import col, to_date, hour, to_timestamp

args = getResolvedOptions(sys.argv, ['JOB_NAME', 'SOURCE_PATH', 'TARGET_PATH'])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

dynamic_frame = glueContext.create_dynamic_frame.from_options(
    connection_type="s3",
    format="json",
    connection_options={
        "paths": [args['SOURCE_PATH']],
        "recurse": True,
        "jobBookmarkKeys": ["event_id"],
        "jobBookmarkKeysSortOrder": "asc"
    },
    transformation_ctx="bronze_input"
)

# Resolve type ambiguities before converting to DataFrame
dynamic_frame = ResolveChoice.apply(dynamic_frame, choice="cast:double", transformation_ctx="resolve_choices")

df = dynamic_frame.toDF()

if df.count() == 0:
    print("No new data to process")
    job.commit()
    import sys
    sys.exit(0)

df_silver = (
    df
    .dropDuplicates(["event_id"])
    .dropna(subset=["event_id", "event_type", "user_id"])
    .filter(col("event_type") != "")
    .withColumn("event_timestamp", to_timestamp(col("event_timestamp")))
    .withColumn("event_date", to_date(col("event_timestamp")))
    .withColumn("event_hour", hour(col("event_timestamp")))
    .withColumn("price", col("price").cast("double"))
    .withColumn("quantity", col("quantity").cast("int"))
)

(
    df_silver
    .repartition("event_type", "event_date")
    .write
    .mode("append")
    .partitionBy("event_type", "event_date")
    .parquet(args['TARGET_PATH'])
)

job.commit()