# Healthcare Data Mesh - Setup Complete! ✓

## What's Been Configured

### 1. Infrastructure ✓
- **MinIO**: S3-compatible storage with buckets created
  - `landing-zone` - for raw FHIR data (254 files uploaded)
  - `healthcare-warehouse` - for Iceberg tables
- **Nessie**: Git-like catalog for data versioning
- **Trino**: SQL query engine with Iceberg connector configured
- **Postgres**: Airflow metadata database
- **Airflow**: Orchestration with webserver and scheduler running

### 2. Data Ingestion ✓
- **Synthea Data**: 259 synthetic FHIR patient records generated
- **MinIO Upload**: 254 FHIR JSON files uploaded to `s3://landing-zone/raw/fhir/`
- **Trino Table**: 44 smaller FHIR bundles loaded into `iceberg.landing.fhir_bundles`

### 3. dbt Models Created ✓
- **sources.yml**: Defines MinIO landing-zone as a dbt source
- **stg_patients.sql**: Comprehensive staging model to flatten FHIR JSON
  - Extracts 30+ patient attributes
  - Handles FHIR R4 Bundle structure
  - Includes demographics, address, race/ethnicity, and quality metrics
- **schema.yml**: Documentation and data quality tests
- **README.md**: Guide for adding new FHIR resource models

### 4. Configuration Files ✓
- **trino/catalog/iceberg.properties**: Iceberg catalog connected to Nessie + MinIO
- **docker-compose.yml**: All services configured with health checks
- **CLAUDE.md**: Comprehensive guide updated with all commands

### 5. Helper Scripts Created ✓
- **scripts/load_fhir_to_trino.py**: Loads small FHIR files via SQL INSERT
- **scripts/upload_fhir_to_minio.py**: Uploads large files directly to MinIO
- **scripts/requirements.txt**: Python dependencies (trino, boto3)

## Current Status

### Data Available
```
Trino Table:  iceberg.landing.fhir_bundles (44 records)
MinIO Bucket: s3://landing-zone/raw/fhir/ (254 files)
Total Patients: 259 synthetic patients generated
```

### Services Running
```
✓ MinIO (localhost:9000, console:9001)
✓ Nessie (localhost:19120)
✓ Trino (localhost:8080)
✓ Airflow (localhost:8081, admin/admin)
✓ Postgres (port 5432)
```

## Next Steps

### 1. Configure dbt Profile

Create `~/.dbt/profiles.yml`:

```yaml
healthcare_mesh:
  target: dev
  outputs:
    dev:
      type: trino
      method: none
      user: admin
      host: localhost
      port: 8080
      catalog: iceberg
      schema: landing
      threads: 4
```

### 2. Run dbt Staging Model

```bash
cd dbt_project
dbt debug  # Verify connection
dbt run --select stg_patients  # Run the model
dbt test --select stg_patients  # Run data quality tests
```

### 3. Query Patient Data

```bash
# Connect to Trino
docker exec -it healthcare_trino trino

# Query staged patients
SELECT * FROM iceberg.landing.stg_patients LIMIT 10;
```

### 4. Alternative: Test without dbt

Query directly in Trino to see flattened patient data:

```sql
WITH fhir_raw AS (
  SELECT json_parse(data) AS bundle_json
  FROM iceberg.landing.fhir_bundles LIMIT 5
),
patient_entries AS (
  SELECT entry_json
  FROM fhir_raw
  CROSS JOIN UNNEST(CAST(json_extract(bundle_json, '$.entry') AS ARRAY(JSON))) AS t(entry_json)
  WHERE json_extract_scalar(entry_json, '$.resource.resourceType') = 'Patient'
)
SELECT
  json_extract_scalar(entry_json, '$.resource.id') AS patient_id,
  json_extract_scalar(entry_json, '$.resource.gender') AS gender,
  json_extract_scalar(entry_json, '$.resource.birthDate') AS birth_date,
  json_extract_scalar(CAST(json_extract(entry_json, '$.resource.name[0]') AS JSON), '$.family') AS last_name,
  json_extract_scalar(CAST(json_extract(entry_json, '$.resource.name[0]') AS JSON), '$.given[0]') AS first_name
FROM patient_entries;
```

### 5. Load More Data (Optional)

The 44 records in the Trino table are sufficient for testing. To load ALL files:
- Option A: Use the Airflow DAG (will sync files from synthea_output to MinIO)
- Option B: Manually process the 254 files already in MinIO

## Architecture Overview

```
Synthea → FHIR JSON files → MinIO (S3) → Trino (Iceberg) → dbt → Analytics
                ↓
            Nessie (version control)
                ↓
            Airflow (orchestration)
```

## Useful Commands

```bash
# Check data in Trino
docker exec healthcare_trino trino --execute "SELECT COUNT(*) FROM iceberg.landing.fhir_bundles;"

# List files in MinIO bucket
docker exec healthcare_airflow_scheduler python3 -c "
import boto3
s3 = boto3.client('s3', endpoint_url='http://healthcare-minio:9000',
                  aws_access_key_id='admin', aws_secret_access_key='password')
print([obj['Key'] for obj in s3.list_objects_v2(Bucket='landing-zone', Prefix='raw/fhir/')['Contents'][:5]])
"

# Trigger Airflow DAG manually
docker exec healthcare_airflow_scheduler airflow dags trigger healthcare_ingestion_v2

# View Nessie branches
curl http://localhost:19120/api/v2/trees | python3 -m json.tool
```

## Troubleshooting

### dbt connection fails
- Verify Trino is running: `docker compose ps trino`
- Test Trino access: `docker exec healthcare_trino trino --execute "SHOW CATALOGS;"`
- Check dbt profile: `dbt debug`

### No data in table
- Run upload script: `python3 scripts/upload_fhir_to_minio.py`
- Run load script: `python3 scripts/load_fhir_to_trino.py`
- Trigger Airflow DAG: See command above

### Services not running
```bash
docker compose up -d  # Start all services
docker compose logs -f [service-name]  # Check logs
```

## Documentation

- **CLAUDE.md**: Full architecture and commands reference
- **dbt_project/models/README.md**: Guide for adding new models
- **Nessie API**: http://localhost:19120/api/v2/trees

---

**Status**: ✅ Infrastructure ready for analytics!
