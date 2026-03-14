from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime
import boto3
import os
import json
import shutil
from trino.dbapi import connect

def get_trino_connection():
    return connect(
        host="trino",
        port=8080,
        user="admin",
        catalog="iceberg",
        schema="landing",
    )

def get_s3_client():
    # Use the service name defined in docker-compose
    return boto3.client(
        's3',
        endpoint_url='http://healthcare-minio:9000',
        aws_access_key_id='admin',
        aws_secret_access_key='password',
        region_name='us-east-1'
    )

def setup_trino_tables():
    conn = get_trino_connection()
    cursor = conn.cursor()
    
    # Ensure landing schema exists in Iceberg
    cursor.execute("CREATE SCHEMA IF NOT EXISTS iceberg.landing WITH (location = 's3a://landing-zone/raw/fhir/')")
    
    # Target Iceberg table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS iceberg.landing.fhir_bundles (
            file_path VARCHAR, 
            data VARCHAR, 
            ingestion_timestamp TIMESTAMP(6) WITH TIME ZONE
        ) WITH (format = 'PARQUET')
    """)
    
    cursor.close()
    conn.close()

def load_fhir_to_trino_incremental():
    s3 = get_s3_client()
    bucket_name = 'landing-zone'
    MAX_FILES = 5 # Limit volume per run
    MAX_FILE_SIZE_BYTES = 5 * 1024 * 1024 # 5MB limit per file
    
    # Ensure bucket exists
    try:
        s3.create_bucket(Bucket=bucket_name)
    except:
        pass

    source_dir = '/opt/airflow/synthea_output/fhir'
    processed_dir = os.path.join(source_dir, 'processed')
    
    if not os.path.exists(source_dir):
        return
        
    os.makedirs(processed_dir, exist_ok=True)

    conn = get_trino_connection()
    cursor = conn.cursor()

    files_processed = 0
    for root, dirs, files in os.walk(source_dir):
        if root != source_dir or files_processed >= MAX_FILES:
            continue
            
        for file in files:
            if files_processed >= MAX_FILES:
                break

            if file.endswith(".json") and not file.startswith(('hospital', 'practitioner')):
                local_path = os.path.join(root, file)
                
                # Check file size before processing
                if os.path.getsize(local_path) > MAX_FILE_SIZE_BYTES:
                    print(f"Skipping {file}: Size exceeds {MAX_FILE_SIZE_BYTES} bytes")
                    # Optionally move to a 'skipped' or 'too_large' folder
                    continue

                try:
                    # 1. Upload to MinIO (Efficient storage)
                    s3_key = f"raw/fhir/{file}"
                    s3.upload_file(local_path, bucket_name, s3_key)
                    
                    # 2. Insert into Trino (Iceberg) for dbt access
                    with open(local_path, 'r') as f:
                        fhir_data = f.read()
                    
                    ingestion_ts = datetime.now()
                    
                    insert_query = "INSERT INTO iceberg.landing.fhir_bundles (file_path, data, ingestion_timestamp) VALUES (?, ?, ?)"
                    cursor.execute(insert_query, (s3_key, fhir_data, ingestion_ts))
                    
                    # Move to processed to avoid double ingestion
                    processed_path = os.path.join(processed_dir, file)
                    shutil.move(local_path, processed_path)
                    print(f"Successfully ingested {file}")
                    files_processed += 1
                    
                except Exception as e:
                    print(f"Error loading {file}: {e}")
                    
    cursor.close()
    conn.close()

with DAG(
    'healthcare_ingestion_incremental',
    start_date=datetime(2026, 3, 8),
    schedule_interval='@hourly',
    catchup=False,
    tags=['ingestion', 'fhir', 'incremental']
) as dag:

    setup_task = PythonOperator(
        task_id='setup_trino_tables',
        python_callable=setup_trino_tables
    )

    load_task = PythonOperator(
        task_id='load_fhir_to_trino_incremental',
        python_callable=load_fhir_to_trino_incremental
    )

    setup_task >> load_task
