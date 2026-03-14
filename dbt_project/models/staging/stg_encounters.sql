{{
  config(
    materialized='incremental',
    unique_key='encounter_id',
    tags=['staging', 'fhir', 'encounters']
  )
}}

WITH fhir_raw AS (
  SELECT
    file_path,
    json_parse(data) AS bundle_json,
    ingestion_timestamp
  FROM {{ source('landing', 'fhir_bundles') }}
  {% if is_incremental() %}
  WHERE ingestion_timestamp > (SELECT MAX(ingestion_timestamp) FROM {{ this }})
  {% endif %}
),

encounter_entries AS (
  SELECT
    file_path,
    ingestion_timestamp,
    entry_json
  FROM fhir_raw
  CROSS JOIN UNNEST(
    CAST(json_extract(bundle_json, '$.entry') AS ARRAY(JSON))
  ) AS t(entry_json)
  WHERE json_extract_scalar(entry_json, '$.resource.resourceType') = 'Encounter'
),

flattened_encounters AS (
  SELECT
    -- Identifiers
    json_extract_scalar(entry_json, '$.resource.id') AS encounter_id,
    
    -- Foreign Keys
    -- The reference is typically "urn:uuid:xxxxx", so we strip the prefix
    REPLACE(
      json_extract_scalar(entry_json, '$.resource.subject.reference'),
      'urn:uuid:',
      ''
    ) AS patient_id,
    
    -- Details
    json_extract_scalar(entry_json, '$.resource.status') AS status,
    json_extract_scalar(
      CAST(json_extract(entry_json, '$.resource.class') AS JSON),
      '$.code'
    ) AS class,
    
    -- Type (extracting first coding description)
    json_extract_scalar(
      CAST(json_extract(entry_json, '$.resource.type[0].coding[0]') AS JSON),
      '$.display'
    ) AS encounter_type,
    
    -- Timing
    CAST(SUBSTR(json_extract_scalar(entry_json, '$.resource.period.start'), 1, 10) AS DATE) AS start_time,
    CAST(SUBSTR(json_extract_scalar(entry_json, '$.resource.period.end'), 1, 10) AS DATE) AS end_time,
    
    -- Provider (first participant)
    REPLACE(
      json_extract_scalar(
        CAST(json_extract(entry_json, '$.resource.participant[0].individual') AS JSON),
        '$.reference'
      ),
      'urn:uuid:',
      ''
    ) AS provider_id,

    -- Metadata
    file_path,
    ingestion_timestamp,
    ingestion_timestamp AS ingested_at,
    CURRENT_TIMESTAMP AS dbt_processed_at

  FROM encounter_entries
)

SELECT * FROM flattened_encounters
