from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime
import boto3
import os

def sync_fhir_to_minio():
    s3 = boto3.client(
        's3',
        endpoint_url='http://healthcare-minio:9000',
        aws_access_key_id='admin',
        aws_secret_access_key='password'
    )
    
    # Path inside Airflow container
    source_dir = '/opt/airflow/synthea_output/fhir'
    bucket_name = 'landing-zone'

    if not os.path.exists(source_dir):
        print(f"Source {source_dir} not found. Synthea might still be running.")
        return

    for root, dirs, files in os.walk(source_dir):
        for file in files:
            if file.endswith(".json"):
                local_path = os.path.join(root, file)
                s3_key = f"raw/fhir/{file}"
                s3.upload_file(local_path, bucket_name, s3_key)
                print(f"Successfully ingested: {file}")

with DAG(
    'healthcare_ingestion_v2',
    start_date=datetime(2026, 3, 8),
    schedule_interval='@hourly',
    catchup=False
) as dag:

    sync_task = PythonOperator(
        task_id='sync_to_minio',
        python_callable=sync_fhir_to_minio
    )