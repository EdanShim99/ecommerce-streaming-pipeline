import sys
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import (
    col,
    countDistinct,
    sum as spark_sum,
    avg,
    round as spark_round,
    when
)

args = getResolvedOptions(sys.argv, ['JOB_NAME', 'SOURCE_PATH', 'TARGET_PATH'])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

df = spark.read.parquet(args['SOURCE_PATH'])

if df.rdd.isEmpty():
    print("No new Silver data to process")
    job.commit()
    sys.exit(0)

# ✅ DAILY SALES (Incremental Safe)
daily_sales = (
    df
    .filter(col("event_type") == "purchase")
    .groupBy("event_date", "category")
    .agg(
        spark_sum(when(col("event_type") == "purchase", 1).otherwise(0)).alias("total_orders"),
        spark_sum(col("price") * col("quantity")).alias("total_revenue"),
        spark_round(avg(col("price") * col("quantity")), 2).alias("avg_order_value"),
        countDistinct("user_id").alias("unique_buyers")
    )
)

daily_sales.write \
    .mode("append") \
    .partitionBy("event_date") \
    .parquet(args['TARGET_PATH'] + "daily_sales/")


# ✅ DAILY PRODUCT PERFORMANCE
daily_products = (
    df
    .groupBy("event_date", "product_id", "product_name", "category")
    .agg(
        spark_sum(when(col("event_type") == "page_view", 1).otherwise(0)).alias("views"),
        spark_sum(when(col("event_type") == "add_to_cart", 1).otherwise(0)).alias("cart_adds"),
        spark_sum(when(col("event_type") == "purchase", 1).otherwise(0)).alias("purchases"),
        spark_sum(
            when(col("event_type") == "purchase",
                 col("price") * col("quantity")
            ).otherwise(0)
        ).alias("total_revenue")
    )
)

daily_products.write \
    .mode("append") \
    .partitionBy("event_date") \
    .parquet(args['TARGET_PATH'] + "product_performance/")


# ✅ DAILY USER ENGAGEMENT
daily_users = (
    df
    .groupBy("event_date", "user_id")
    .agg(
        spark_sum(when(col("event_id").isNotNull(), 1).otherwise(0)).alias("total_events"),
        countDistinct("session_id").alias("total_sessions"),
        countDistinct("product_id").alias("products_interacted"),
        spark_sum(when(col("event_type") == "purchase", 1).otherwise(0)).alias("total_purchases")
    )
)

daily_users.write \
    .mode("append") \
    .partitionBy("event_date") \
    .parquet(args['TARGET_PATH'] + "user_engagement/")

job.commit()