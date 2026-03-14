{{
  config(
    materialized='table',
    tags=['marts', 'core', 'patients']
  )
}}

WITH patients AS (
    SELECT * FROM {{ ref('stg_patients') }}
),

encounters AS (
    SELECT 
        patient_id,
        MIN(start_time) AS first_encounter_date,
        MAX(start_time) AS last_encounter_date,
        COUNT(*) AS total_encounters
    FROM {{ ref('stg_encounters') }}
    GROUP BY 1
),

final AS (
    SELECT
        p.patient_id,
        p.given_name,
        p.family_name,
        p.gender,
        p.birth_date,
        p.address_line,
        p.city,
        p.state,
        p.postal_code,
        p.country,
        p.phone_number,
        p.primary_language,
        p.race,
        p.ethnicity,
        p.marital_status,
        e.first_encounter_date,
        e.last_encounter_date,
        COALESCE(e.total_encounters, 0) AS total_encounters,
        DATE_DIFF('year', p.birth_date, CURRENT_DATE) AS age_years,
        p.ingested_at,
        CURRENT_TIMESTAMP AS dbt_updated_at
    FROM patients p
    LEFT JOIN encounters e ON p.patient_id = e.patient_id
)

SELECT * FROM final
