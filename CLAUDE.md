# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a healthcare data mesh implementation using a modern lakehouse architecture. The system generates synthetic FHIR healthcare data (via Synthea), ingests it into object storage (MinIO), and provides SQL query capabilities (via Trino/Iceberg/Nessie) with orchestration via Apache Airflow and transformation via dbt.

## Architecture

### Core Components

**Data Flow:**
1. **Synthea** generates synthetic FHIR healthcare data (JSON)
2. **Airflow DAG** (`clinical_ingestion_dag.py`) syncs FHIR files from local volume to MinIO
3. **MinIO** provides S3-compatible object storage (buckets: `landing-zone`, `healthcare-warehouse`)
4. **Trino** queries data via Iceberg table format
5. **Nessie** provides Git-like data versioning and catalog management
6. **dbt** transforms raw data into analytics-ready models

**Stack Layers:**
- Storage: MinIO (S3-compatible)
- Catalog: Nessie (Git for data)
- Compute: Trino with Iceberg connector
- Orchestration: Apache Airflow
- Transformation: dbt-trino
- Data Generation: Synthea

### Service Connectivity

- MinIO: `http://healthcare-minio:9000` (console: `9001`)
- Airflow Web UI: `http://localhost:8081` (admin/admin)
- Trino: `http://healthcare_trino:8080`
- Nessie: `http://nessie:19120/api/v2`
- Postgres (Airflow metadata): `postgres:5432`

All services communicate via the `healthcare_mesh_net` Docker network.

### Data Locations

- Synthea output: `./synthea_output/fhir/` (FHIR JSON files)
- Airflow DAGs: `./airflow/dags/`
- dbt project: `./dbt_project/`
- Trino catalog config: `./trino/catalog/iceberg.properties`

## Common Commands

### Starting the Environment

```bash
# Start all services
docker compose up -d

# Start specific services
docker compose up -d minio nessie trino

# View logs
docker compose logs -f [service-name]

# Stop all services
docker compose down
```

### Airflow Operations

```bash
# Access Airflow scheduler logs
docker compose logs -f airflow-scheduler

# Trigger DAG manually
docker exec healthcare_airflow_scheduler airflow dags trigger healthcare_ingestion_v2

# List DAGs
docker exec healthcare_airflow_scheduler airflow dags list
```

### Synthea Data Generation

```bash
# Generate new synthetic patients (runs once and exits)
docker compose run --rm synthea-gen
```

### dbt Operations

```bash
# Run dbt commands (requires dbt profile configured in ~/.dbt/profiles.yml)
docker compose run --rm dbt debug
docker compose run --rm dbt compile
docker compose run --rm dbt run
docker compose run --rm dbt test

# Run dbt locally (if dbt-trino installed)
cd dbt_project
dbt debug
dbt run
```

### Trino Queries

```bash
# Connect to Trino CLI
docker exec -it healthcare_trino trino

# Example queries:
# SHOW CATALOGS;
# SHOW SCHEMAS IN iceberg;
# SHOW TABLES IN iceberg.landing;
# SELECT * FROM iceberg.landing.fhir_bundles LIMIT 10;

# Non-interactive query execution
docker exec healthcare_trino trino --execute "SELECT COUNT(*) FROM iceberg.landing.fhir_bundles;"
```

### Loading FHIR Data into Trino

```bash
# Install Python dependencies
pip install -r scripts/requirements.txt

# Load FHIR JSON files from synthea_output into Trino
python scripts/load_fhir_to_trino.py
```

### MinIO Operations

```bash
# Access MinIO console at http://localhost:9001
# Credentials: admin/password

# List buckets (from inside any container with boto3)
docker exec healthcare_airflow_scheduler python3 -c "
import boto3
s3 = boto3.client('s3', endpoint_url='http://healthcare-minio:9000',
                  aws_access_key_id='admin', aws_secret_access_key='password')
print(s3.list_buckets())
"
```

## Key Configuration Files

### Trino Iceberg Catalog

File: `trino/catalog/iceberg.properties`

Connects Trino to Nessie catalog with MinIO as storage backend. Uses:
- Nessie for metadata versioning (`http://nessie:19120/api/v2`)
- MinIO for object storage (`http://minio:9000`, S3-compatible)
- Path-style S3 access (required for MinIO)
- S3 region set to `us-east-1` (required even for MinIO)

### dbt Profile

Expected location: `~/.dbt/profiles.yml`

Should configure a profile named `healthcare_mesh` targeting Trino with the Iceberg catalog.

### Airflow DAG

File: `airflow/dags/clinical_ingestion_dag.py`

- Runs hourly (`@hourly` schedule)
- Syncs FHIR JSON files from `/opt/airflow/synthea_output/fhir` to MinIO bucket `landing-zone` under `raw/fhir/`
- Uses boto3 with MinIO endpoint

## Development Workflow

1. **Generate Data**: Run `synthea-gen` to create synthetic FHIR patients
2. **Ingest Data**: Airflow DAG automatically syncs files to MinIO (or trigger manually)
3. **Query Raw Data**: Use Trino to explore data in `landing-zone` bucket
4. **Transform Data**: Create dbt models in `dbt_project/models/` to build analytics tables
5. **Version Control**: Nessie tracks table versions and metadata changes

## Nessie Branching & Data Versioning

Nessie provides Git-like version control for your data catalog. Use branches to isolate schema changes and transformations before merging to production.

### Creating a Branch

```bash
# Create a new branch from main (using Nessie REST API)
curl -X POST http://localhost:19120/api/v2/trees/branch/dev_clinical \
  -H "Content-Type: application/json" \
  -d '{"name": "dev_clinical", "reference": "main"}'

# List all branches
curl http://localhost:19120/api/v2/trees
```

### Using a Branch in Trino

```sql
-- Connect to Trino CLI
docker exec -it healthcare_trino trino

-- Switch to your branch (use AT BRANCH syntax)
USE iceberg.dev_clinical;

-- Create tables on the branch
CREATE TABLE iceberg.dev_clinical.patients_cleaned AS
SELECT * FROM iceberg.landing.patients WHERE ...;

-- View branch-specific tables
SHOW TABLES IN iceberg.dev_clinical;
```

### Using a Branch in dbt

Configure your dbt profile to target a specific Nessie branch by setting the `ref` parameter in your connection string or using environment variables:

```yaml
# In ~/.dbt/profiles.yml
healthcare_mesh:
  target: dev
  outputs:
    dev:
      type: trino
      catalog: iceberg
      schema: dev_clinical  # Your Nessie branch name
      # ... other connection details
```

### Merging a Branch

```bash
# Merge dev_clinical branch into main
curl -X POST http://localhost:19120/api/v2/trees/branch/main/merge \
  -H "Content-Type: application/json" \
  -d '{"fromRefName": "dev_clinical", "message": "Merge clinical transformations"}'

# Verify merge
curl http://localhost:19120/api/v2/trees/branch/main/log
```

### Best Practices

- Create a new branch for each feature or schema change (e.g., `dev_clinical`, `feat_patient_analytics`)
- Test dbt models on a branch before merging to `main`
- Use meaningful commit messages when merging branches
- Delete branches after successful merge to keep catalog clean
- Use `main` branch for production queries and dashboards

## Important Notes

- All containers run as user `50000:0` (Airflow default) for consistency
- MinIO credentials are hardcoded (`admin/password`) - not for production
- Airflow uses LocalExecutor with Postgres backend
- The dbt project currently has no models - create them in `dbt_project/models/`
- Synthea generates Massachusetts population by default (20 patients per run)
- FHIR data follows HL7 FHIR R4 specification

## Data Governance & Standards
- **Data Standard:** HL7 FHIR R4 (JSON format).
- **PII/PHI Policy:** This repository uses 100% synthetic data generated by Synthea. No real Patient Health Information (PHI) is permitted.
- **Versioning:** Project Nessie provides Git-like semantics (commit/merge/branch) for the Iceberg tables.
- **Nessie Branching:** For schema changes or new dbt models, create a Nessie branch (e.g., `dev_clinical`) to test transformations in isolation before merging to `main`. See the "Nessie Branching & Data Versioning" section for detailed commands.

## CI/CD Workflow
- **GitHub Actions:** Located in `.github/workflows/dbt_ci.yml`.
- **Validation:** Every Pull Request triggers a `dbt parse` and `dbt compile` to ensure SQL integrity.
- **Automation:** Merges to `main` should ideally trigger an Airflow dataset refresh.