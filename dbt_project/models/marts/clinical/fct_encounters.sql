{{
  config(
    unique_key='encounter_id',
    tags=['marts', 'clinical', 'encounters']
  )
}}

WITH encounters AS (
    SELECT * FROM {{ ref('stg_encounters') }}
    {% if is_incremental() %}
    WHERE ingested_at > (SELECT MAX(ingested_at) FROM {{ this }})
    {% endif %}
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
        e.encounter_id,
        e.patient_id,
        e.status AS encounter_status,
        e.class AS encounter_class,
        e.encounter_type,
        e.start_time,
        e.end_time,
        e.provider_id,
        DATE_DIFF('day', e.start_time, e.end_time) AS duration_days,
        p.gender AS patient_gender,
        p.birth_date AS patient_birth_date,
        p.city AS patient_city,
        p.state AS patient_state,
        p.race AS patient_race,
        p.ethnicity AS patient_ethnicity,
        DATE_DIFF('year', p.birth_date, CAST(e.start_time AS DATE)) AS patient_age_at_encounter,
        e.ingested_at,
        CURRENT_TIMESTAMP AS dbt_updated_at
    FROM encounters e
    LEFT JOIN patients p ON e.patient_id = p.patient_id
)

SELECT * FROM final
