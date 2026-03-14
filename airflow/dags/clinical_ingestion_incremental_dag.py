from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime
import boto3
import os
import json
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
    cursor.execute("CREATE SCHEMA IF NOT EXISTS iceberg.landing")
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS iceberg.landing.fhir_bundles (
            file_path VARCHAR, 
            data VARCHAR, 
            ingestion_timestamp TIMESTAMP(6) WITH TIME ZONE
        ) WITH (format = 'PARQUET')
    """)
    cursor.close()
    conn.close()

def load_fhir_from_s3_to_trino():
    s3 = get_s3_client()
    bucket_name = 'landing-zone'
    prefix = 'raw/fhir/'
    MAX_FILES = 100
    SIZE_LIMIT = 3 * 1024 * 1024 # 3MB

    # 1. List files in S3
    response = s3.list_objects_v2(Bucket=bucket_name, Prefix=prefix)
    if 'Contents' not in response:
        print("No files found in S3.")
        return

    conn = get_trino_connection()
    cursor = conn.cursor()

    # 2. Get already ingested files to avoid duplicates
    cursor.execute("SELECT DISTINCT file_path FROM iceberg.landing.fhir_bundles")
    ingested_files = {row[0] for row in cursor.fetchall()}

    # 3. Prepare staging
    cursor.execute("DROP TABLE IF EXISTS memory.default.staging_ingest")
    cursor.execute("CREATE TABLE memory.default.staging_ingest (file_path VARCHAR, data VARCHAR)")

    files_processed = 0
    for obj in response['Contents']:
        s3_key = obj['Key']
        
        # Skip directories, non-json, or already ingested
        if s3_key.endswith('/') or not s3_key.endswith('.json') or s3_key in ingested_files:
            continue
            
        if obj['Size'] > SIZE_LIMIT:
            print(f"Skipping {s3_key}: Size {obj['Size']} exceeds 3MB limit")
            continue

        try:
            # Download content
            file_obj = s3.get_object(Bucket=bucket_name, Key=s3_key)
            fhir_data = file_obj['Body'].read().decode('utf-8')
            
            # Insert into Memory staging
            cursor.execute("INSERT INTO memory.default.staging_ingest (file_path, data) VALUES (?, ?)", (s3_key, fhir_data))
            print(f"Staged {s3_key}")
            
            files_processed += 1
            if files_processed >= MAX_FILES:
                break
        except Exception as e:
            print(f"Error processing {s3_key}: {e}")

    if files_processed > 0:
        # 4. Bulk move to Iceberg
        cursor.execute("""
            INSERT INTO iceberg.landing.fhir_bundles (file_path, data, ingestion_timestamp)
            SELECT file_path, data, current_timestamp
            FROM memory.default.staging_ingest
        """)
        print(f"Successfully ingested {files_processed} files to Iceberg.")
    else:
        print("No new files to ingest.")

    cursor.close()
    conn.close()

with DAG(
    'healthcare_ingestion_incremental',
    start_date=datetime(2026, 3, 8),
    schedule_interval='@hourly',
    catchup=False,
    tags=['ingestion', 'fhir', 's3', 'incremental']
) as dag:

    setup_task = PythonOperator(
        task_id='setup_trino_tables',
        python_callable=setup_trino_tables
    )

    load_task = PythonOperator(
        task_id='load_fhir_to_trino_incremental',
        python_callable=load_fhir_from_s3_to_trino
    )

    setup_task >> load_task
