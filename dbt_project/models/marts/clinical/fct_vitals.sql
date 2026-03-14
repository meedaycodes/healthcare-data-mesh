{{
  config(
    materialized='table',
    tags=['marts', 'clinical', 'vitals']
  )
}}

WITH observations AS (
    SELECT * FROM {{ ref('stg_observations') }}
),

patients AS (
    SELECT
        patient_id,
        gender,
        birth_date,
        city,
        state,
        race,
        ethnicity
    FROM {{ ref('stg_patients') }}
),

final AS (
    SELECT
        o.observation_id,
        o.patient_id,
        o.encounter_id,
        o.category,
        o.observation_code,
        o.observation_description,
        o.value_quantity,
        o.value_unit,
        o.effective_date,
        p.gender AS patient_gender,
        p.race AS patient_race,
        p.ethnicity AS patient_ethnicity,
        DATE_DIFF('year', p.birth_date, CAST(o.effective_date AS DATE)) AS patient_age_at_observation,
        o.ingested_at,
        CURRENT_TIMESTAMP AS dbt_updated_at
    FROM observations o
    LEFT JOIN patients p ON o.patient_id = p.patient_id
)

SELECT * FROM final
