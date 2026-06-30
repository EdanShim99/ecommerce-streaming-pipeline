# Create root directory
mkdir ecommerce-streaming
cd ecommerce-streaming

# Create Python Event Generator
touch event_generator.py

# Create venv
python3 -m venv venv
source venv/bin/activate

# Create environment file with AWS credentials
touch .env

# Create Project Structure
mkdir -p terraform glue .github/workflows
touch Dockerfile docker-compose.yml requirements.txt README.md .gitignore

# Install dependencies
pip install boto3
pip freeze > requirements.txt

# Create Terraform Folder
cd terraform
touch provider.tf variables.tf s3.tf kinesis.tf firehose.tf glue.tf step_functions.tf eventbridge.tf athena.tf monitoring.tf

# Initialize Terraform
terraform init
terraform validate
terraform plan

# Deploy Infrastructure
terraform apply -var="alert_email=email@example.com"

# Create Glue Scripts
cd ../glue
touch bronze_to_silver.py
touch silver_to_gold.py 

# Run Event Generator via Docker
docker-compose build
docker-compose up

# Go to AWS Console and trigger Step Functions 'ecommerce-etl-pipeline'

# Teardown
terraform destroy -var="alert_email=your-email@example.com"