import streamlit as st
import plotly.express as px
import plotly.graph_objects as go
from db_utils import (
    get_patient_demographics,
    get_top_conditions,
    get_top_medications,
    get_encounter_trends,
    get_vitals_summary
)

st.set_page_config(
    page_title="Healthcare Data Mesh BI",
    page_icon="🏥",
    layout="wide"
)

st.title("🏥 Healthcare Data Mesh Analytics")
st.markdown("""
This dashboard provides real-time insights from the Healthcare Data Mesh Lakehouse.
Data is sourced from synthetic FHIR records transformed via dbt and served through Trino.
""")

# Sidebar for filters or navigation
st.sidebar.header("Dashboard Controls")
refresh_btn = st.sidebar.button("Refresh Data")

# --- KPI Section ---
col1, col2, col3, col4 = st.columns(4)

with col1:
    demo_df = get_patient_demographics()
    st.metric("Total Patients", len(demo_df))

with col2:
    conditions_df = get_top_conditions()
    st.metric("Unique Conditions", len(conditions_df))

with col3:
    meds_df = get_top_medications()
    st.metric("Active Medications", meds_df['count'].sum())

with col4:
    trends_df = get_encounter_trends()
    st.metric("Latest Month Vol", trends_df['count'].iloc[-1] if not trends_df.empty else 0)

st.divider()

# --- Main Layout ---
tab1, tab2, tab3 = st.tabs(["Demographics & Trends", "Clinical Analysis", "Vitals & Observations"])

with tab1:
    c1, c2 = st.columns(2)
    with c1:
        st.subheader("Patient Age Distribution")
        fig_age = px.histogram(demo_df, x="age_years", color="gender", 
                               nbins=20, title="Age by Gender")
        st.plotly_chart(fig_age, use_container_width=True)
    
    with c2:
        st.subheader("Race Distribution")
        fig_race = px.pie(demo_df, names="race", hole=0.4)
        st.plotly_chart(fig_race, use_container_width=True)

    st.subheader("Encounter Volume Over Time")
    fig_trends = px.line(trends_df, x="month", y="count", markers=True)
    st.plotly_chart(fig_trends, use_container_width=True)

with tab2:
    c1, c2 = st.columns(2)
    with c1:
        st.subheader("Top 10 Diagnoses")
        fig_cond = px.bar(conditions_df, x="count", y="condition_description", 
                          orientation='h', color="count")
        st.plotly_chart(fig_cond, use_container_width=True)

    with c2:
        st.subheader("Top 10 Medications")
        fig_meds = px.bar(meds_df, x="count", y="medication_description", 
                         orientation='h', color_discrete_sequence=['#ff7f0e'])
        st.plotly_chart(fig_meds, use_container_width=True)

with tab3:
    st.subheader("Population Vitals Summary")
    vitals_df = get_vitals_summary()
    st.dataframe(vitals_df, use_container_width=True)
    
    if not vitals_df.empty:
        selected_vital = st.selectbox("Select Vital to Visualize Average", vitals_df['observation_description'].unique())
        vital_subset = vitals_df[vitals_df['observation_description'] == selected_vital]
        st.info(f"Average {selected_vital}: {vital_subset['avg_value'].values[0]:.2f} {vital_subset['value_unit'].values[0]}")

st.sidebar.markdown("---")
st.sidebar.info("Powered by Trino + Iceberg + Nessie")
