{{
  config(
    tags=['staging', 'fhir', 'patients']
  )
}}

WITH fhir_raw AS (
  SELECT
    file_path,
    json_parse(data) AS bundle_json,
    ingestion_timestamp
  FROM {{ source('landing', 'fhir_bundles') }}
),

patient_entries AS (
  SELECT
    file_path,
    ingestion_timestamp,
    entry_json
  FROM fhir_raw
  CROSS JOIN UNNEST(
    CAST(json_extract(bundle_json, '$.entry') AS ARRAY(JSON))
  ) AS t(entry_json)
  WHERE json_extract_scalar(entry_json, '$.resource.resourceType') = 'Patient'
),

flattened_patients AS (
  SELECT
    -- Primary identifiers
    json_extract_scalar(entry_json, '$.resource.id') AS patient_id,
    json_extract_scalar(entry_json, '$.fullUrl') AS patient_full_url,

    -- Demographics
    json_extract_scalar(entry_json, '$.resource.gender') AS gender,
    CAST(json_extract_scalar(entry_json, '$.resource.birthDate') AS DATE) AS birth_date,

    -- Name (extracting first official name)
    json_extract_scalar(
      CAST(json_extract(entry_json, '$.resource.name[0]') AS JSON),
      '$.family'
    ) AS family_name,
    json_extract_scalar(
      CAST(json_extract(entry_json, '$.resource.name[0]') AS JSON),
      '$.given[0]'
    ) AS given_name,
    json_extract_scalar(
      CAST(json_extract(entry_json, '$.resource.name[0]') AS JSON),
      '$.given[1]'
    ) AS middle_name,

    -- Address (extracting first address)
    json_extract_scalar(
      CAST(json_extract(entry_json, '$.resource.address[0]') AS JSON),
      '$.line[0]'
    ) AS address_line,
    json_extract_scalar(
      CAST(json_extract(entry_json, '$.resource.address[0]') AS JSON),
      '$.city'
    ) AS city,
    json_extract_scalar(
      CAST(json_extract(entry_json, '$.resource.address[0]') AS JSON),
      '$.state'
    ) AS state,
    json_extract_scalar(
      CAST(json_extract(entry_json, '$.resource.address[0]') AS JSON),
      '$.postalCode'
    ) AS postal_code,
    json_extract_scalar(
      CAST(json_extract(entry_json, '$.resource.address[0]') AS JSON),
      '$.country'
    ) AS country,

    -- Geolocation
    CAST(json_extract_scalar(
      CAST(json_extract(entry_json, '$.resource.address[0].extension[0].extension[0]') AS JSON),
      '$.valueDecimal'
    ) AS DOUBLE) AS latitude,
    CAST(json_extract_scalar(
      CAST(json_extract(entry_json, '$.resource.address[0].extension[0].extension[1]') AS JSON),
      '$.valueDecimal'
    ) AS DOUBLE) AS longitude,

    -- Contact
    json_extract_scalar(
      CAST(json_extract(entry_json, '$.resource.telecom[0]') AS JSON),
      '$.value'
    ) AS phone_number,

    -- Marital Status
    json_extract_scalar(
      CAST(json_extract(entry_json, '$.resource.maritalStatus') AS JSON),
      '$.text'
    ) AS marital_status,

    -- Language
    json_extract_scalar(
      CAST(json_extract(entry_json, '$.resource.communication[0].language') AS JSON),
      '$.text'
    ) AS primary_language,

    -- Race (from US Core extension - index 0)
    json_extract_scalar(
      CAST(json_extract(entry_json, '$.resource.extension[0].extension[1]') AS JSON),
      '$.valueString'
    ) AS race,

    -- Ethnicity (from US Core extension - index 1)
    json_extract_scalar(
      CAST(json_extract(entry_json, '$.resource.extension[1].extension[1]') AS JSON),
      '$.valueString'
    ) AS ethnicity,

    -- Birth Sex (from US Core extension - index 3)
    json_extract_scalar(
      entry_json,
      '$.resource.extension[3].valueCode'
    ) AS birth_sex,

    -- Mother's Maiden Name (extension index 2)
    json_extract_scalar(
      entry_json,
      '$.resource.extension[2].valueString'
    ) AS mothers_maiden_name,

    -- Birth Place (extension index 4)
    json_extract_scalar(
      CAST(json_extract(entry_json, '$.resource.extension[4].valueAddress') AS JSON),
      '$.city'
    ) AS birth_city,
    json_extract_scalar(
      CAST(json_extract(entry_json, '$.resource.extension[4].valueAddress') AS JSON),
      '$.state'
    ) AS birth_state,

    -- Multiple Birth
    CAST(json_extract_scalar(entry_json, '$.resource.multipleBirthInteger') AS INTEGER) AS multiple_birth_order,

    -- Quality metrics (Synthea-specific - extension indices 5 and 6)
    CAST(json_extract_scalar(
      entry_json,
      '$.resource.extension[6].valueDecimal'
    ) AS DOUBLE) AS quality_adjusted_life_years,
    CAST(json_extract_scalar(
      entry_json,
      '$.resource.extension[5].valueDecimal'
    ) AS DOUBLE) AS disability_adjusted_life_years,

    -- Metadata
    file_path,
    ingestion_timestamp,
    ingestion_timestamp AS ingested_at,
    CURRENT_TIMESTAMP AS dbt_processed_at

  FROM patient_entries
)

SELECT * FROM flattened_patients
