import os
import streamlit as st
import pandas as pd
from trino.dbapi import connect
from trino.auth import BasicAuthentication
from dotenv import load_dotenv

load_dotenv()

# Configuration from environment
TRINO_HOST = os.getenv("TRINO_HOST", "trino")
TRINO_PORT = int(os.getenv("TRINO_PORT", 8080))
TRINO_USER = os.getenv("TRINO_USER", "admin")
TRINO_CATALOG = os.getenv("TRINO_CATALOG", "iceberg")
TRINO_SCHEMA = os.getenv("TRINO_SCHEMA", "landing_gold")

@st.cache_resource
def get_trino_connection():
    return connect(
        host=TRINO_HOST,
        port=TRINO_PORT,
        user=TRINO_USER,
        catalog=TRINO_CATALOG,
        schema=TRINO_SCHEMA,
        http_scheme="http",
    )

@st.cache_data(ttl=600)
def run_query(query: str) -> pd.DataFrame:
    conn = get_trino_connection()
    cur = conn.cursor()
    cur.execute(query)
    rows = cur.fetchall()
    columns = [desc[0] for desc in cur.description]
    return pd.DataFrame(rows, columns=columns)

def get_patient_demographics():
    query = "SELECT gender, race, ethnicity, age_years FROM dim_patients"
    return run_query(query)

def get_top_conditions():
    query = """
    SELECT condition_description, COUNT(*) as count 
    FROM fct_conditions 
    GROUP BY condition_description 
    ORDER BY count DESC 
    LIMIT 10
    """
    return run_query(query)

def get_top_medications():
    query = """
    SELECT medication_description, COUNT(*) as count 
    FROM fct_medications 
    GROUP BY medication_description 
    ORDER BY count DESC 
    LIMIT 10
    """
    return run_query(query)

def get_encounter_trends():
    query = """
    SELECT date_trunc('month', start_time) as month, COUNT(*) as count 
    FROM fct_encounters 
    GROUP BY 1 
    ORDER BY 1
    """
    return run_query(query)

def get_vitals_summary():
    query = """
    SELECT observation_description, AVG(value_quantity) as avg_value, value_unit, COUNT(*) as sample_size
    FROM fct_vitals
    WHERE value_quantity IS NOT NULL
    GROUP BY observation_description, value_unit
    HAVING COUNT(*) > 10
    ORDER BY sample_size DESC
    """
    return run_query(query)
