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

def setup_trino_tables():
    conn = get_trino_connection()
    cursor = conn.cursor()
    cursor.execute("CREATE SCHEMA IF NOT EXISTS iceberg.landing WITH (location = 's3a://landing-zone/raw/fhir/')")
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS iceberg.landing.fhir_bundles (
            file_path VARCHAR, 
            data VARCHAR, 
            ingestion_timestamp TIMESTAMP(6) WITH TIME ZONE
        ) WITH (format = 'PARQUET')
    """)
    cursor.close()
    conn.close()

def load_fhir_to_trino():
    conn = get_trino_connection()
    cursor = conn.cursor()
    source_dir = '/opt/airflow/synthea_output/fhir'
    
    if not os.path.exists(source_dir):
        return

    # Delete existing records to allow re-runs
    cursor.execute("DELETE FROM iceberg.landing.fhir_bundles")

    for root, dirs, files in os.walk(source_dir):
        if root != source_dir:
            continue
            
        for file in files:
            if file.endswith(".json") and not file.startswith(('hospital', 'practitioner')):
                local_path = os.path.join(root, file)
                try:
                    with open(local_path, 'r') as f:
                        fhir_data = f.read()
                    
                    json.loads(fhir_data) # Validate JSON
                    
                    ingestion_ts = datetime.now()
                    s3_key = f"raw/fhir/{file}"
                    
                    insert_query = """
                        INSERT INTO fhir_bundles (file_path, data, ingestion_timestamp)
                        VALUES (?, ?, ?)
                    """
                    cursor.execute(insert_query, (s3_key, fhir_data, ingestion_ts))
                except Exception as e:
                    print(f"Error loading {file}: {e}")
                    
    cursor.close()
    conn.close()

with DAG(
    'healthcare_ingestion_v2',
    start_date=datetime(2026, 3, 8),
    schedule_interval='@hourly',
    catchup=False
) as dag:

    setup_task = PythonOperator(
        task_id='setup_trino_tables',
        python_callable=setup_trino_tables
    )

    load_task = PythonOperator(
        task_id='load_fhir_to_trino',
        python_callable=load_fhir_to_trino
    )

    setup_task >> load_task