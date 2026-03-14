{{
  config(
    tags=['staging', 'fhir', 'allergies']
  )
}}

WITH fhir_raw AS (
  SELECT
    file_path,
    json_parse(data) AS bundle_json,
    ingestion_timestamp
  FROM {{ source('landing', 'fhir_bundles') }}
),

allergy_entries AS (
  SELECT
    file_path,
    ingestion_timestamp,
    entry_json
  FROM fhir_raw
  CROSS JOIN UNNEST(
    CAST(json_extract(bundle_json, '$.entry') AS ARRAY(JSON))
  ) AS t(entry_json)
  WHERE json_extract_scalar(entry_json, '$.resource.resourceType') = 'AllergyIntolerance'
),

flattened_allergies AS (
  SELECT
    -- Identifiers
    json_extract_scalar(entry_json, '$.resource.id') AS allergy_id,
    
    -- Foreign Keys
    REPLACE(
      json_extract_scalar(entry_json, '$.resource.patient.reference'),
      'urn:uuid:',
      ''
    ) AS patient_id,
    
    -- Details
    json_extract_scalar(entry_json, '$.resource.clinicalStatus.coding[0].code') AS clinical_status,
    json_extract_scalar(entry_json, '$.resource.verificationStatus.coding[0].code') AS verification_status,
    json_extract_scalar(entry_json, '$.resource.type') AS allergy_type,
    json_extract_scalar(entry_json, '$.resource.category[0]') AS category,
    json_extract_scalar(entry_json, '$.resource.criticality') AS criticality,
    
    -- Code and Description
    json_extract_scalar(
      CAST(json_extract(entry_json, '$.resource.code.coding[0]') AS JSON),
      '$.code'
    ) AS allergy_code,
    
    json_extract_scalar(
      CAST(json_extract(entry_json, '$.resource.code.coding[0]') AS JSON),
      '$.display'
    ) AS allergy_description,
    
    -- Timing
    from_iso8601_timestamp(
      json_extract_scalar(entry_json, '$.resource.recordedDate')
    ) AS recorded_date,

    -- Metadata
    file_path,
    ingestion_timestamp,
    ingestion_timestamp AS ingested_at,
    CURRENT_TIMESTAMP AS dbt_processed_at

  FROM allergy_entries
)

SELECT * FROM flattened_allergies
