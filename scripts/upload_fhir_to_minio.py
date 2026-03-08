#!/usr/bin/env python3
"""
Upload FHIR JSON files directly to MinIO landing-zone bucket.

This script bypasses Trino's query size limit by uploading files directly to S3.
Files can then be read by Trino using external table or dbt models.

Usage:
    python scripts/upload_fhir_to_minio.py
"""

import os
import boto3
from datetime import datetime

# MinIO connection settings
MINIO_ENDPOINT = "http://localhost:9000"
MINIO_ACCESS_KEY = "admin"
MINIO_SECRET_KEY = "password"
BUCKET_NAME = "landing-zone"
S3_PREFIX = "raw/fhir/"

# Source directory
FHIR_DIR = "./synthea_output/fhir"


def upload_fhir_files():
    """Upload all FHIR JSON files to MinIO."""

    if not os.path.exists(FHIR_DIR):
        print(f"Error: Directory {FHIR_DIR} does not exist")
        return

    # Create S3 client
    s3 = boto3.client(
        's3',
        endpoint_url=MINIO_ENDPOINT,
        aws_access_key_id=MINIO_ACCESS_KEY,
        aws_secret_access_key=MINIO_SECRET_KEY
    )

    # Get list of FHIR JSON files (exclude metadata files)
    fhir_files = [
        f for f in os.listdir(FHIR_DIR)
        if f.endswith('.json') and not f.startswith(('hospital', 'practitioner'))
    ]

    print(f"Found {len(fhir_files)} FHIR files to upload")
    print(f"Uploading to s3://{BUCKET_NAME}/{S3_PREFIX}\n")

    uploaded_count = 0
    error_count = 0

    for filename in fhir_files:
        file_path = os.path.join(FHIR_DIR, filename)
        s3_key = f"{S3_PREFIX}{filename}"

        try:
            # Get file size
            file_size = os.path.getsize(file_path)

            # Upload file with metadata
            s3.upload_file(
                file_path,
                BUCKET_NAME,
                s3_key,
                ExtraArgs={
                    'Metadata': {
                        'ingestion_timestamp': datetime.now().isoformat(),
                        'original_filename': filename,
                        'source': 'synthea'
                    }
                }
            )

            uploaded_count += 1
            if uploaded_count % 50 == 0:
                print(f"Uploaded {uploaded_count}/{len(fhir_files)} files...")

        except Exception as e:
            error_count += 1
            print(f"Error uploading {filename}: {str(e)}")

    print(f"\n=== Upload Summary ===")
    print(f"Successfully uploaded: {uploaded_count}")
    print(f"Errors: {error_count}")
    print(f"Total files: {len(fhir_files)}")

    return uploaded_count, error_count


def list_uploaded_files(limit=10):
    """List files in the MinIO bucket to verify upload."""
    s3 = boto3.client(
        's3',
        endpoint_url=MINIO_ENDPOINT,
        aws_access_key_id=MINIO_ACCESS_KEY,
        aws_secret_access_key=MINIO_SECRET_KEY
    )

    response = s3.list_objects_v2(
        Bucket=BUCKET_NAME,
        Prefix=S3_PREFIX,
        MaxKeys=limit
    )

    if 'Contents' not in response:
        print("\nNo files found in bucket")
        return

    print(f"\nSample files in s3://{BUCKET_NAME}/{S3_PREFIX}:")
    for obj in response['Contents'][:limit]:
        size_mb = obj['Size'] / (1024 * 1024)
        print(f"  - {obj['Key']} ({size_mb:.2f} MB)")

    # Get total count
    total_response = s3.list_objects_v2(Bucket=BUCKET_NAME, Prefix=S3_PREFIX)
    total_count = total_response.get('KeyCount', 0)
    print(f"\nTotal files in bucket: {total_count}")


if __name__ == "__main__":
    print("=== FHIR Data Uploader to MinIO ===\n")
    upload_fhir_files()
    list_uploaded_files(limit=5)
    print("\nDone! Files are now available in MinIO at:")
    print(f"  s3://{BUCKET_NAME}/{S3_PREFIX}")
    print("\nYou can now query them using dbt models that read directly from S3.")
