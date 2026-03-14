{{
  config(
    tags=['staging', 'fhir', 'immunizations']
  )
}}

WITH fhir_raw AS (
  SELECT
    file_path,
    json_parse(data) AS bundle_json,
    ingestion_timestamp
  FROM {{ source('landing', 'fhir_bundles') }}
),

immunization_entries AS (
  SELECT
    file_path,
    ingestion_timestamp,
    entry_json
  FROM fhir_raw
  CROSS JOIN UNNEST(
    CAST(json_extract(bundle_json, '$.entry') AS ARRAY(JSON))
  ) AS t(entry_json)
  WHERE json_extract_scalar(entry_json, '$.resource.resourceType') = 'Immunization'
),

flattened_immunizations AS (
  SELECT
    -- Identifiers
    json_extract_scalar(entry_json, '$.resource.id') AS immunization_id,
    
    -- Foreign Keys
    REPLACE(
      json_extract_scalar(entry_json, '$.resource.patient.reference'),
      'urn:uuid:',
      ''
    ) AS patient_id,
    
    REPLACE(
      json_extract_scalar(entry_json, '$.resource.encounter.reference'),
      'urn:uuid:',
      ''
    ) AS encounter_id,

    -- Details
    json_extract_scalar(entry_json, '$.resource.status') AS status,
    
    -- Code and Description
    json_extract_scalar(
      CAST(json_extract(entry_json, '$.resource.vaccineCode.coding[0]') AS JSON),
      '$.code'
    ) AS vaccine_code,
    
    json_extract_scalar(
      CAST(json_extract(entry_json, '$.resource.vaccineCode.coding[0]') AS JSON),
      '$.display'
    ) AS vaccine_description,
    
    -- Timing
    from_iso8601_timestamp(
      json_extract_scalar(entry_json, '$.resource.occurrenceDateTime')
    ) AS occurrence_date,

    -- Metadata
    file_path,
    ingestion_timestamp,
    ingestion_timestamp AS ingested_at,
    CURRENT_TIMESTAMP AS dbt_processed_at

  FROM immunization_entries
)

SELECT * FROM flattened_immunizations
