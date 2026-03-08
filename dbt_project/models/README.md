# dbt Models

This directory contains dbt models for transforming raw FHIR healthcare data into analytics-ready tables.

## Structure

- **sources.yml** - Defines the raw data sources from MinIO landing zone
- **schema.yml** - Documents staging models and defines data quality tests
- **stg_patients.sql** - Flattens FHIR Patient resources from JSON bundles

## Data Flow

```
MinIO (landing-zone/raw/fhir/*.json)
  ↓
Trino Iceberg (landing.fhir_bundles)
  ↓
dbt staging layer (stg_patients)
  ↓
dbt marts layer (coming soon)
```

## Adding New Models

1. Create the SQL model file (e.g., `stg_encounters.sql`)
2. Document it in `schema.yml` with column descriptions and tests
3. Run `dbt compile` to validate SQL syntax
4. Run `dbt run` to materialize the model
5. Run `dbt test` to verify data quality

## FHIR Resources to Model

- **Patient** ✅ (`stg_patients.sql`)
- **Encounter** - Future: patient encounters with providers
- **Observation** - Future: vital signs, lab results
- **Condition** - Future: diagnoses and problems
- **Procedure** - Future: medical procedures
- **MedicationRequest** - Future: prescriptions
- **Immunization** - Future: vaccination records
- **AllergyIntolerance** - Future: allergies

## Testing Strategy

All staging models include:
- Unique and not_null tests on primary keys
- Accepted values tests for categorical fields
- Source freshness checks (configured in sources.yml)

Run tests with:
```bash
dbt test --select stg_patients
```
