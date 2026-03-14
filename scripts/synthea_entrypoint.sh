#!/bin/bash
set -e

echo "Starting Synthea generation..."
# Run Synthea (original command)
java -jar synthea.jar -p "${PATIENT_COUNT:-20}" --exporter.fhir.export=true --exporter.baseDirectory=./output/

echo "Generation complete. Syncing to MinIO..."

# Configure AWS CLI for MinIO
export AWS_ACCESS_KEY_ID=${MINIO_ROOT_USER:-admin}
export AWS_SECRET_ACCESS_KEY=${MINIO_ROOT_PASSWORD:-password}
export AWS_DEFAULT_REGION=us-east-1

# Sync generated FHIR files to MinIO
# We use the internal service name 'minio' or 'healthcare-minio'
aws --endpoint-url http://healthcare-minio:9000 s3 sync ./output/fhir/ s3://landing-zone/raw/fhir/ --quiet

echo "Sync to MinIO complete."
