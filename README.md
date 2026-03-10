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
| **Orchestration** | [Apache Airflow](https://airflow.apache.org/) | Workflow management and ingestion pipelines. |

---

## 📈 Data Pipeline & Flow

```mermaid
graph LR
    subgraph "Ingestion & Storage"
        S[Synthea] -->|FHIR JSON| L[Local FS]
        L -->|Airflow Sync| M[MinIO S3]
    end

    subgraph "Lakehouse Architecture"
        M <--> I[Apache Iceberg]
        I <--> N[Nessie Catalog]
        I <--> T[Trino SQL]
    end

    subgraph "Transformation Layer"
        T --> D[dbt Models]
        D -->|Flattened| P[Patients]
        D -->|Flattened| E[Encounters]
    end

    subgraph "Analytics & BI"
        P --> A[BI / Analysts]
        E --> A
    end
```

---

## 🚀 Quick Start

### 1. Prerequisite Checklist
- **Docker & Docker Compose** (Desktop or Server)
- **Python 3.11+** (for local CLI utilities)
- **Make** (standard on Linux/macOS)

### 2. Infrastructure Setup
```bash
# Clone the repository
git clone https://github.com/your-username/healthcare-data-mesh.git
cd healthcare-data-mesh

# Initialize all services (MinIO, Nessie, Trino, Airflow, Postgres)
docker compose up -d

# Verify connectivity (Trino CLI)
docker exec -it healthcare_trino trino --execute "SHOW CATALOGS;"
```

### 3. End-to-End Pipeline
```bash
# Generate 20 synthetic patients
make generate

# Trigger incremental ingestion via Airflow
make ingest_incremental

# Build and test dbt transformation models
make dbt_build
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
