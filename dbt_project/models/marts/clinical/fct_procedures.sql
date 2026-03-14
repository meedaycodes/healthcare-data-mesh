{{
  config(
    unique_key='procedure_id',
    tags=['marts', 'clinical', 'procedures']
  )
}}

WITH procedures AS (
    SELECT * FROM {{ ref('stg_procedures') }}
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
        pr.procedure_id,
        pr.patient_id,
        pr.encounter_id,
        pr.status AS procedure_status,
        pr.procedure_code,
        pr.procedure_description,
        pr.start_date,
        pr.end_date,
        DATE_DIFF('minute', 
            CAST(pr.start_date AS TIMESTAMP), 
            CAST(COALESCE(pr.end_date, pr.start_date) AS TIMESTAMP)
        ) AS duration_minutes,
        p.gender AS patient_gender,
        p.race AS patient_race,
        DATE_DIFF('year', p.birth_date, pr.start_date) AS patient_age_at_procedure,
        pr.ingested_at,
        CURRENT_TIMESTAMP AS dbt_updated_at
    FROM procedures pr
    LEFT JOIN patients p ON pr.patient_id = p.patient_id
)

SELECT * FROM final
