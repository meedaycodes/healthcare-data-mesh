{{
  config(
    materialized='table',
    tags=['staging', 'fhir', 'conditions']
  )
}}

WITH fhir_raw AS (
  SELECT
    file_path,
    json_parse(data) AS bundle_json,
    ingestion_timestamp
  FROM {{ source('landing', 'fhir_bundles') }}
),

condition_entries AS (
  SELECT
    file_path,
    ingestion_timestamp,
    entry_json
  FROM fhir_raw
  CROSS JOIN UNNEST(
    CAST(json_extract(bundle_json, '$.entry') AS ARRAY(JSON))
  ) AS t(entry_json)
  WHERE json_extract_scalar(entry_json, '$.resource.resourceType') = 'Condition'
),

flattened_conditions AS (
  SELECT
    -- Identifiers
    json_extract_scalar(entry_json, '$.resource.id') AS condition_id,
    
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
    json_extract_scalar(
      CAST(json_extract(entry_json, '$.resource.clinicalStatus.coding[0]') AS JSON),
      '$.code'
    ) AS clinical_status,
    
    json_extract_scalar(
      CAST(json_extract(entry_json, '$.resource.verificationStatus.coding[0]') AS JSON),
      '$.code'
    ) AS verification_status,
    
    -- Code and Description
    json_extract_scalar(
      CAST(json_extract(entry_json, '$.resource.code.coding[0]') AS JSON),
      '$.code'
    ) AS condition_code,
    
    json_extract_scalar(
      CAST(json_extract(entry_json, '$.resource.code.coding[0]') AS JSON),
      '$.display'
    ) AS condition_description,
    
    -- Timing
    CAST(SUBSTR(json_extract_scalar(entry_json, '$.resource.onsetDateTime'), 1, 10) AS DATE) AS onset_date,
    CAST(SUBSTR(json_extract_scalar(entry_json, '$.resource.abatementDateTime'), 1, 10) AS DATE) AS abatement_date,

    -- Metadata
    file_path,
    ingestion_timestamp,
    CURRENT_TIMESTAMP AS dbt_processed_at

  FROM condition_entries
)

SELECT * FROM flattened_conditions
