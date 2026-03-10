{{
  config(
    materialized='table',
    tags=['staging', 'fhir', 'observations']
  )
}}

WITH fhir_raw AS (
  SELECT
    file_path,
    json_parse(data) AS bundle_json,
    ingestion_timestamp
  FROM {{ source('landing', 'fhir_bundles') }}
),

observation_entries AS (
  SELECT
    file_path,
    ingestion_timestamp,
    entry_json
  FROM fhir_raw
  CROSS JOIN UNNEST(
    CAST(json_extract(bundle_json, '$.entry') AS ARRAY(JSON))
  ) AS t(entry_json)
  WHERE json_extract_scalar(entry_json, '$.resource.resourceType') = 'Observation'
),

flattened_observations AS (
  SELECT
    -- Identifiers
    json_extract_scalar(entry_json, '$.resource.id') AS observation_id,
    
    -- Foreign Keys
    REPLACE(
      json_extract_scalar(entry_json, '$.resource.subject.reference'),
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
    
    -- Category
    json_extract_scalar(
      CAST(json_extract(entry_json, '$.resource.category[0].coding[0]') AS JSON),
      '$.code'
    ) AS category,
    
    -- Code and Description
    json_extract_scalar(
      CAST(json_extract(entry_json, '$.resource.code.coding[0]') AS JSON),
      '$.code'
    ) AS observation_code,
    
    json_extract_scalar(
      CAST(json_extract(entry_json, '$.resource.code.coding[0]') AS JSON),
      '$.display'
    ) AS observation_description,
    
    -- Value
    CAST(json_extract_scalar(
      CAST(json_extract(entry_json, '$.resource.valueQuantity') AS JSON),
      '$.value'
    ) AS DOUBLE) AS value_quantity,
    
    json_extract_scalar(
      CAST(json_extract(entry_json, '$.resource.valueQuantity') AS JSON),
      '$.unit'
    ) AS value_unit,

    -- Timing
    from_iso8601_timestamp(
      json_extract_scalar(entry_json, '$.resource.effectiveDateTime')
    ) AS effective_date,

    -- Metadata
    file_path,
    ingestion_timestamp,
    CURRENT_TIMESTAMP AS dbt_processed_at

  FROM observation_entries
)

SELECT * FROM flattened_observations
