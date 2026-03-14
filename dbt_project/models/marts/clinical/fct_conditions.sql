
{{
  config(
    unique_key='condition_id',
    tags=['marts', 'clinical', 'conditions']
  )
}}

WITH conditions AS (
    SELECT * FROM {{ ref('stg_conditions') }}
    {% if is_incremental() %}
    WHERE ingested_at > (SELECT MAX(ingested_at) FROM {{ this }})
    {% endif %}
),

patients AS (
    SELECT
        patient_id,
        gender,
        race,
        birth_date
    FROM {{ ref('stg_patients') }}
),

final AS (
    SELECT
        c.condition_id,
        c.patient_id,
        c.encounter_id,
        c.clinical_status,
        c.verification_status,
        c.condition_code,
        c.condition_description,
        c.onset_date,
        c.abatement_date,
        p.gender AS patient_gender,
        p.race AS patient_race,
        DATE_DIFF('year', p.birth_date, c.onset_date) AS patient_age_at_onset,
        CASE 
            WHEN c.abatement_date IS NULL THEN 'Active'
            ELSE 'Resolved'
        END AS condition_lifecycle_status,
        c.ingested_at,
        CURRENT_TIMESTAMP AS dbt_updated_at
    FROM conditions c
    LEFT JOIN patients p ON c.patient_id = p.patient_id
)

SELECT * FROM final
