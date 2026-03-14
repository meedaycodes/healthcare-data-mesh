{{
  config(
    unique_key='medication_request_id',
    tags=['marts', 'clinical', 'medications']
  )
}}

WITH medication_requests AS (
    SELECT * FROM {{ ref('stg_medication_requests') }}
    {% if is_incremental() %}
    WHERE ingested_at > (SELECT MAX(ingested_at) FROM {{ this }})
    {% endif %}
),

patients AS (
    SELECT
        patient_id,
        gender,
        race,
        ethnicity,
        birth_date
    FROM {{ ref('stg_patients') }}
),

final AS (
    SELECT
        m.medication_request_id,
        m.patient_id,
        m.encounter_id,
        m.status AS medication_status,
        m.intent AS medication_intent,
        m.medication_code,
        m.medication_description,
        m.authored_date,
        p.gender AS patient_gender,
        p.race AS patient_race,
        DATE_DIFF('year', p.birth_date, CAST(m.authored_date AS DATE)) AS patient_age_at_request,
        m.ingested_at,
        CURRENT_TIMESTAMP AS dbt_updated_at
    FROM medication_requests m
    LEFT JOIN patients p ON m.patient_id = p.patient_id
)

SELECT * FROM final
