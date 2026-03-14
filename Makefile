.PHONY: help generate ingest_incremental ingest_full dbt_build pipeline_incremental pipeline_full nessie_branch nessie_list nessie_merge

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
	Transformation:
		@echo "  make dbt_build           - Run and test all dbt models"
		@echo ""
		@echo "Visualization:"
		@echo "  make viz_up              - Start the Streamlit BI dashboard"
		@echo "  make viz_down            - Stop the Streamlit BI dashboard"
		@echo ""
		@echo "Data Versioning (Nessie):"

	@echo "  make nessie_branch       - Create a new branch (usage: make nessie_branch name=dev_clinical)"
	@echo "  make nessie_list         - List all branches and commits"
	@echo "  make nessie_merge        - Merge branch to main (usage: make nessie_merge name=dev_clinical)"
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
	@echo "Running dbt transformations and tests (branch: $${NESSIE_BRANCH:-main})..."
	docker compose run --rm --entrypoint dbt -e DBT_PROFILES_DIR=/usr/app/dbt_project -e NESSIE_BRANCH=$${NESSIE_BRANCH:-main} dbt build
	@echo "dbt models built and tested successfully!"

# Nessie Management
nessie_branch:
	@if [ -z "$(name)" ]; then echo "Error: Missing parameter 'name'. Use 'make nessie_branch name=my_branch'"; exit 1; fi
	@echo "Creating Nessie branch: $(name)..."
	curl -X POST http://localhost:19120/api/v2/trees/branch/$(name) \
	  -H "Content-Type: application/json" \
	  -d '{"name": "$(name)", "reference": "main"}'
	@echo "\nBranch created!"

nessie_list:
	@echo "Listing Nessie branches..."
	curl -s http://localhost:19120/api/v2/trees | jq '.references[] | {name: .name, type: .type, hash: .hash}' || curl -s http://localhost:19120/api/v2/trees

nessie_merge:
	@if [ -z "$(name)" ]; then echo "Error: Missing parameter 'name'. Use 'make nessie_merge name=my_branch'"; exit 1; fi
	@echo "Merging Nessie branch: $(name) -> main..."
	curl -X POST http://localhost:19120/api/v2/trees/branch/main/merge \
	  -H "Content-Type: application/json" \
	  -d '{"fromRefName": "$(name)", "message": "Merging $(name) clinical transformations"}'
	@echo "\nMerge complete!"

# Composite Commands
pipeline_incremental: generate ingest_incremental
pipeline_full: generate ingest_full

# Visualization
viz_up:
	@echo "Starting Streamlit BI dashboard..."
	docker compose up -d streamlit
	@echo "Dashboard is starting! Access it at http://localhost:8501"

viz_down:
	@echo "Stopping Streamlit BI dashboard..."
	docker compose stop streamlit
