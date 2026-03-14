{{
  config(
    tags=['staging', 'fhir', 'procedures']
  )
}}

WITH fhir_raw AS (
  SELECT
    file_path,
    json_parse(data) AS bundle_json,
    ingestion_timestamp
  FROM {{ source('landing', 'fhir_bundles') }}
),

procedure_entries AS (
  SELECT
    file_path,
    ingestion_timestamp,
    entry_json
  FROM fhir_raw
  CROSS JOIN UNNEST(
    CAST(json_extract(bundle_json, '$.entry') AS ARRAY(JSON))
  ) AS t(entry_json)
  WHERE json_extract_scalar(entry_json, '$.resource.resourceType') = 'Procedure'
),

flattened_procedures AS (
  SELECT
    -- Identifiers
    json_extract_scalar(entry_json, '$.resource.id') AS procedure_id,
    
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
    
    -- Code and Description
    json_extract_scalar(
      CAST(json_extract(entry_json, '$.resource.code.coding[0]') AS JSON),
      '$.code'
    ) AS procedure_code,
    
    json_extract_scalar(
      CAST(json_extract(entry_json, '$.resource.code.coding[0]') AS JSON),
      '$.display'
    ) AS procedure_description,
    
    -- Timing
    CAST(SUBSTR(json_extract_scalar(entry_json, '$.resource.performedPeriod.start'), 1, 10) AS DATE) AS start_date,
    CAST(SUBSTR(json_extract_scalar(entry_json, '$.resource.performedPeriod.end'), 1, 10) AS DATE) AS end_date,

    -- Metadata
    file_path,
    ingestion_timestamp,
    ingestion_timestamp AS ingested_at,
    CURRENT_TIMESTAMP AS dbt_processed_at

  FROM procedure_entries
),

deduplicated AS (
  SELECT * FROM (
    SELECT 
      *,
      row_number() OVER (PARTITION BY procedure_id ORDER BY ingestion_timestamp DESC) as rn
    FROM flattened_procedures
  ) WHERE rn = 1
)

SELECT * FROM deduplicated
