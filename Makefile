.PHONY: help generate ingest_incremental ingest_full dbt_build pipeline_incremental pipeline_full

help:
	@echo "Healthcare Data Mesh - Available Commands"
	@echo "========================================="
	@echo "Data Generation:"
	@echo "  make generate            - Generate new synthetic patients using Synthea"
	@echo ""
	@echo "Ingestion Pipeline:"
	@echo "  make ingest_incremental  - Incrementally load NEW patients into the Data Lake"
	@echo "  make ingest_full         - Wipe and reload all raw patients into the Data Lake"
	@echo ""
	@echo "Transformation:"
	@echo "  make dbt_build           - Run and test all dbt models"
	@echo ""
	@echo "End-to-End Workflows:"
	@echo "  make pipeline_incremental - Generate data -> Incremental load -> dbt build"
	@echo "  make pipeline_full        - Generate data -> Full refresh load -> dbt build"

generate:
	@echo "Starting Synthea container to generate new patients..."
	docker compose up synthea-gen
	@echo "Data generation complete. Files are in ./synthea_output/fhir/"

ingest_incremental:
	@echo "Triggering incremental ingestion Airflow DAG..."
	docker exec healthcare_airflow_scheduler airflow dags unpause healthcare_ingestion_incremental || true
	docker exec healthcare_airflow_scheduler airflow dags trigger healthcare_ingestion_incremental
	@echo "Incremental ingestion triggered! Check Airflow UI to monitor."

ingest_full:
	@echo "Triggering full refresh ingestion Airflow DAG..."
	docker exec healthcare_airflow_scheduler airflow dags unpause healthcare_ingestion_v2 || true
	docker exec healthcare_airflow_scheduler airflow dags trigger healthcare_ingestion_v2
	@echo "Full refresh ingestion triggered! Check Airflow UI to monitor."

dbt_build:
	@echo "Running dbt transformations and tests..."
	docker compose run --rm --entrypoint dbt -e DBT_PROFILES_DIR=/usr/app/dbt_project dbt build
	@echo "dbt models built and tested successfully!"

# Composite Commands
pipeline_incremental: generate ingest_incremental
pipeline_full: generate ingest_full
