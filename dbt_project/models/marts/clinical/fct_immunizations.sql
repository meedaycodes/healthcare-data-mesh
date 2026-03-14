{{
  config(
    unique_key='immunization_id',
    tags=['marts', 'clinical', 'immunizations']
  )
}}

WITH immunizations AS (
    SELECT * FROM {{ ref('stg_immunizations') }}
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
        i.immunization_id,
        i.patient_id,
        i.encounter_id,
        i.status AS immunization_status,
        i.vaccine_code,
        i.vaccine_description,
        i.occurrence_date,
        p.gender AS patient_gender,
        p.race AS patient_race,
        DATE_DIFF('year', p.birth_date, CAST(i.occurrence_date AS DATE)) AS patient_age_at_immunization,
        i.ingested_at,
        CURRENT_TIMESTAMP AS dbt_updated_at
    FROM immunizations i
    LEFT JOIN patients p ON i.patient_id = p.patient_id
)

SELECT * FROM final
