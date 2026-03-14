{{
  config(
    tags=['staging', 'fhir', 'medications']
  )
}}

WITH fhir_raw AS (
  SELECT
    file_path,
    json_parse(data) AS bundle_json,
    ingestion_timestamp
  FROM {{ source('landing', 'fhir_bundles') }}
),

medication_request_entries AS (
  SELECT
    file_path,
    ingestion_timestamp,
    entry_json
  FROM fhir_raw
  CROSS JOIN UNNEST(
    CAST(json_extract(bundle_json, '$.entry') AS ARRAY(JSON))
  ) AS t(entry_json)
  WHERE json_extract_scalar(entry_json, '$.resource.resourceType') = 'MedicationRequest'
),

flattened_medication_requests AS (
  SELECT
    -- Identifiers
    json_extract_scalar(entry_json, '$.resource.id') AS medication_request_id,
    
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

    REPLACE(
      json_extract_scalar(entry_json, '$.resource.requester.reference'),
      'urn:uuid:',
      ''
    ) AS requester_id,

    -- Details
    json_extract_scalar(entry_json, '$.resource.status') AS status,
    json_extract_scalar(entry_json, '$.resource.intent') AS intent,
    
    -- Code and Description
    json_extract_scalar(
      CAST(json_extract(entry_json, '$.resource.medicationCodeableConcept.coding[0]') AS JSON),
      '$.code'
    ) AS medication_code,
    
    json_extract_scalar(
      CAST(json_extract(entry_json, '$.resource.medicationCodeableConcept.coding[0]') AS JSON),
      '$.display'
    ) AS medication_description,
    
    -- Timing
    from_iso8601_timestamp(
      json_extract_scalar(entry_json, '$.resource.authoredOn')
    ) AS authored_date,

    -- Metadata
    file_path,
    ingestion_timestamp,
    ingestion_timestamp AS ingested_at,
    CURRENT_TIMESTAMP AS dbt_processed_at

  FROM medication_request_entries
)

SELECT * FROM flattened_medication_requests
