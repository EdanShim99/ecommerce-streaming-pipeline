import sys
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import col, countDistinct, count, sum as spark_sum, avg, round as spark_round

args = getResolvedOptions(sys.argv, ['JOB_NAME', 'SOURCE_PATH', 'TARGET_PATH'])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

df = spark.read.parquet(args['SOURCE_PATH'])

# Daily sales summary
sales = (
    df
    .filter(col("event_type") == "purchase")
    .groupBy("event_date", "category")
    .agg(
        count("event_id").alias("total_orders"),
        spark_sum(col("price") * col("quantity")).alias("total_revenue"),
        spark_round(avg(col("price") * col("quantity")), 2).alias("avg_order_value"),
        countDistinct("user_id").alias("unique_buyers")
    )
)

sales.write.mode("overwrite").partitionBy("event_date").parquet(args['TARGET_PATH'] + "daily_sales/")

# Product performance
products = (
    df
    .groupBy("product_id", "product_name", "category")
    .agg(
        count(col("event_type") == "page_view").alias("views"),
        count(col("event_type") == "add_to_cart").alias("cart_adds"),
        count(col("event_type") == "purchase").alias("purchases"),
        spark_sum(
            col("price") * col("quantity")
        ).alias("total_revenue")
    )
)

products.write.mode("overwrite").parquet(args['TARGET_PATH'] + "product_performance/")

# User engagement
users = (
    df
    .groupBy("user_id")
    .agg(
        count("event_id").alias("total_events"),
        countDistinct("session_id").alias("total_sessions"),
        countDistinct("product_id").alias("products_interacted"),
        count(col("event_type") == "purchase").alias("total_purchases")
    )
)

users.write.mode("overwrite").parquet(args['TARGET_PATH'] + "user_engagement/")

job.commit()