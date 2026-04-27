# E-Commerce Real-Time Streaming Data Pipeline

A real-time data pipeline that ingests simulated e-commerce events, processes them through a medallion architecture (bronze → silver → gold), and serves aggregated analytics via Athena. All infrastructure is provisioned with Terraform and orchestrated with AWS Step Functions.

## Architecture
Event Generator (Docker)  
▼  
Kinesis Data Stream  
▼  
Kinesis Firehose  
▼  
S3 Bronze (raw JSON)  
▼  
AWS Step Functions Pipeline  
▼  
Glue Job: Bronze → Silver (Parquet)  
▼  
Glue Job: Silver → Gold (aggregated)  
▼  
Glue Crawler (catalog gold tables)  
▼  
Athena (SQL queries on gold tables)

## Tech Stack

- **Ingestion:** Kinesis Data Stream, Kinesis Firehose
- **Storage:** S3 (medallion architecture)
- **Processing:** AWS Glue (PySpark ETL)
- **Orchestration:** AWS Step Functions, Amazon EventBridge
- **Analytics:** Amazon Athena
- **Monitoring:** CloudWatch Alarms, SNS email alerts
- **Infrastructure:** Terraform
- **CI/CD:** GitHub Actions (terraform validate + plan)
- **Containerization:** Docker, Docker Compose

## How It Works

### Event Generator

A Dockerized Python script simulates realistic e-commerce user behavior. Each user session follows a natural flow: browsing → viewing products → adding to cart → purchasing. Events include page views, product views, add-to-cart, remove-from-cart, purchases, and searches. Events are sent to Kinesis Data Stream in real time.

### Medallion Architecture

**Bronze** — Kinesis Firehose delivers raw JSON events to S3, buffered in 60-second intervals. This is the immutable, append-only raw layer.

**Silver** — A Glue job reads the raw JSON, flattens nested fields (product details, event metadata), removes duplicates by event ID, adds a processing timestamp, and writes clean Parquet files. Glue job bookmarks track what has already been processed so each run only handles new data.

**Gold** — A second Glue job reads the silver Parquet and produces three business-level aggregation tables:

- **daily_sales** — revenue, order count, and average order value grouped by date
- **product_performance** — view, cart, and purchase counts per product with conversion metrics
- **user_engagement** — session count, event count, and spending per user

### Orchestration

AWS Step Functions runs the full ETL sequence: bronze-to-silver job → silver-to-gold job → gold crawler → poll until crawler finishes. EventBridge triggers this pipeline on a daily schedule. If any step fails, SNS sends an email alert via CloudWatch.

### Analytics

After the gold crawler catalogs the output, the three gold tables are immediately queryable in Athena using standard SQL.

## Prerequisites

- AWS account with CLI configured (`aws configure`)
- Terraform installed
- Docker and Docker Compose installed
- Git

## Deployment

### 1. Clone the Repo
git clone https://github.com/<your-username>/ecommerce-streaming.git
cd ecommerce-streaming

### 2. Deploy Infrastructure
terraform init
terraform apply -var="alert_email=your-email@example.com"

### 3. Generate Events
docker-compose up --build

### 4. Run ETL Pipeline
Go to AWS Step Functions, find ecommerce-etl-pipeline, and start execution

### 5. Query in Athena
3 Available tables: daily_sales, product_performance, user_engagement

## Teardown
terraform destroy -var="alert_email=your-email@example.com"