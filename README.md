# Healthcare Data Mesh: Synthetic FHIR Lakehouse

[![dbt-ci](https://github.com/habeeb-a/healthcare-data-mesh/actions/workflows/dbt_ci.yml/badge.svg)](https://github.com/habeeb-a/healthcare-data-mesh/actions/workflows/dbt_ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A high-performance, version-controlled **Healthcare Data Mesh** implementation designed for scalable analytics on synthetic HL7 FHIR R4 data. This project demonstrates a modern **Lakehouse Architecture** combining the best of data lakes (object storage flexibility) and data warehouses (ACID transactions, structured queries).

---

## 🏛️ Architectural Philosophy

In traditional healthcare data environments, data often resides in silos or brittle ETL pipelines. This project addresses these challenges through:

- **Data-as-a-Product:** Decentralized data management where clinical domains (Encounters, Patients, Observations) are treated as first-class citizens.
- **Git-for-Data:** Leveraging **Project Nessie** for metadata versioning, enabling branching, merging, and isolation of data changes.
- **Open Standards:** Built on **Apache Iceberg** for high-performance table management and **HL7 FHIR R4** for clinical data interoperability.
- **Unified Compute:** **Trino** serves as the distributed SQL engine, providing a single interface for ingestion, transformation, and analytics.
- **Actionable Insights:** Integrated **Streamlit** BI layer for real-time visualization of clinical and operational KPIs.

---

## 🛠️ Technology Stack

| Layer | Component | Description |
| :--- | :--- | :--- |
| **Data Generation** | [Synthea™](https://github.com/synthetichealth/synthea) | Realistic, synthetic patient records. |
| **Object Storage** | [MinIO](https://min.io/) | High-performance, S3-compatible storage. |
| **Table Format** | [Apache Iceberg](https://iceberg.apache.org/) | ACID transactions, partition evolution, schema evolution. |
| **Catalog / Versioning** | [Project Nessie](https://projectnessie.org/) | Metadata versioning with Git-like semantics. |
| **Compute Engine** | [Trino](https://trino.io/) | Distributed SQL for massive datasets. |
| **Transformation** | [dbt-trino](https://github.com/starburstdata/dbt-trino) | SQL-based ELT with testing and documentation. |
| **Visualization (BI)** | [Streamlit](https://streamlit.io/) | Interactive dashboards for clinical analytics. |
| **Orchestration** | [Apache Airflow](https://airflow.apache.org/) | Workflow management and ingestion pipelines. |

---

## 📈 Data Pipeline & Flow

> **Note on Ingestion Performance:** To ensure stability within Trino's memory constraints, the ingestion pipeline is configured to process files with a **3MB individual file size limit** using a high-speed Memory Staging pattern. Files exceeding this limit are skipped to prevent OOM (Out of Memory) errors.

For a detailed visual representation of the data flow and component interactions, please refer to the **[Architecture & Dataflow Diagram](DATAFLOW_DIAGRAM.md)**.

---

---

## 🚀 Quick Start

### 1. Prerequisite Checklist
- **Docker & Docker Compose** (Desktop or Server)
- **Python 3.11+** (for local CLI utilities)
- **Make** (standard on Linux/macOS)

### 2. Infrastructure Setup
```bash
# Clone the repository
git clone https://github.com/meedaycodes/healthcare-data-mesh.git
cd healthcare-data-mesh

# Initialize all services (MinIO, Nessie, Trino, Airflow, Postgres, Streamlit)
docker compose up -d

# Verify connectivity (Trino CLI)
docker exec -it healthcare_trino trino --execute "SHOW CATALOGS;"
```

### 3. First-Run Bootstrap
The generation and initial data load are manual steps to populate your Lakehouse.
```bash
# 1. Generate synthetic patients (auto-syncs to MinIO S3)
make generate

# 2. Perform initial BOOTSTRAP load into Iceberg
make ingest_full

# 3. Build and test dbt transformation models
make dbt_build
```

### 4. Ongoing Ingestion
Once bootstrapped, **Airflow automatically runs the incremental ingestion every hour**. You can monitor this in the Airflow UI at `http://localhost:8081`.

To manually trigger an incremental update:
```bash
make ingest_incremental
```

### 5. Launch BI Dashboard
```bash
make viz_up
```

---

## 🧪 Data Governance & Quality

High-quality clinical data requires rigorous validation. This project implements:

- **Schema Enforcement:** Via Iceberg, ensuring data consistency at the storage layer.
- **Staging Quality Gates:** Every `stg_*.sql` model includes:
    - `unique`: No duplicate IDs (e.g., `patient_id`).
    - `not_null`: Critical clinical fields must be present.
    - `accepted_values`: Categorical data (gender, status) must match FHIR standards.
- **CI/CD Integration:** Automated [GitHub Actions](.github/workflows/dbt_ci.yml) validate SQL syntax and model parsing on every Pull Request.

---

## 📊 Data Marts (Analytics Ready)

The transformation layer produces several analytics-ready models in the `marts` directory:

- **`core.dim_patients`**: A consolidated patient dimension table including calculated age, location, and encounter frequency.
- **`clinical.fct_encounters`**: A fact table of clinical encounters with patient demographics and visit duration.
- **`clinical.fct_conditions`**: Longitudinal history of diagnoses and health status.
- **`clinical.fct_medications`**: Detailed prescribing history and medication intent.
- **`clinical.fct_vitals`**: A specialized fact table surfacing patient vitals and laboratory results for clinical analysis.

---

## 🔧 Scaling Ingestion

If you need to ingest larger FHIR bundles or increase the volume per run, you must scale the infrastructure constraints:

1. **Trino Query Length:** Increase `query.max-length` in `trino/config.properties` (value is in bytes).
2. **Trino Memory:** 
   - Increase `-Xmx` in `trino/jvm.config`.
   - Increase the Docker `memory` limits and `reservations` for the `trino` service in `docker-compose.yml`.
3. **Airflow DAG Constraints:** Update `MAX_FILES` and `MAX_FILE_SIZE_BYTES` in `airflow/dags/clinical_ingestion_incremental_dag.py`.

---

## 🔧 Advanced Usage: Data Versioning (Nessie)

Project Nessie allows you to treat your data catalog like a Git repository. You can create branches for experimentation without affecting production data:

```bash
# Create a new experimental branch via REST API
curl -X POST http://localhost:19120/api/v2/trees/branch/dev_clinical_v2 \
  -H "Content-Type: application/json" \
  -d '{"name": "dev_clinical_v2", "reference": "main"}'

# Query the branch in Trino (using Nessie's reference)
# SET SESSION iceberg.non_transactional_merge = true;
# SELECT * FROM iceberg.landing.stg_patients FOR VERSION AS OF 'dev_clinical_v2';
```

---

## 📂 Project Structure

- `airflow/dags/`: Orchestration logic for incremental and full ingestions.
- `dbt_project/`: The core transformation logic (SQL models, tests, sources).
- `viz/`: Streamlit dashboard application and visualization logic.
- `scripts/`: Python-based utilities for direct MinIO/Trino interaction.
- `synthea_output/`: Local staging for generated patient records.
- `trino/catalog/`: Catalog configurations defining Iceberg/Nessie connections.

---

## 🤝 Contributing

We welcome contributions! Please see [CLAUDE.md](CLAUDE.md) for detailed technical guidelines, coding standards, and common development commands.

---

**Architectural Status**: ✅ Production Prototype Operational
**Data Standard**: HL7 FHIR R4
**Security Policy**: 100% Synthetic Data - **No real PII/PHI allowed.**
