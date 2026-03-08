#!/usr/bin/env python3
"""
Load FHIR JSON files from synthea_output into Trino Iceberg table.

Usage:
    python scripts/load_fhir_to_trino.py
"""

import os
import json
from datetime import datetime
from trino.dbapi import connect

# Trino connection settings
TRINO_HOST = "localhost"
TRINO_PORT = 8080
TRINO_USER = "admin"
TRINO_CATALOG = "iceberg"
TRINO_SCHEMA = "landing"

# Source directory
FHIR_DIR = "./synthea_output/fhir"


def get_trino_connection():
    """Create a connection to Trino."""
    return connect(
        host=TRINO_HOST,
        port=TRINO_PORT,
        user=TRINO_USER,
        catalog=TRINO_CATALOG,
        schema=TRINO_SCHEMA,
    )


def load_fhir_files():
    """Load all FHIR JSON files into the fhir_bundles table."""

    if not os.path.exists(FHIR_DIR):
        print(f"Error: Directory {FHIR_DIR} does not exist")
        return

    conn = get_trino_connection()
    cursor = conn.cursor()

    # Get list of FHIR JSON files (exclude metadata files)
    fhir_files = [
        f for f in os.listdir(FHIR_DIR)
        if f.endswith('.json') and not f.startswith(('hospital', 'practitioner'))
    ]

    print(f"Found {len(fhir_files)} FHIR files to load")

    loaded_count = 0
    error_count = 0

    for filename in fhir_files:
        file_path = os.path.join(FHIR_DIR, filename)

        try:
            # Read the JSON file
            with open(file_path, 'r') as f:
                fhir_data = f.read()

            # Validate JSON
            json.loads(fhir_data)

            # Prepare data for insertion
            ingestion_ts = datetime.now()
            relative_path = f"raw/fhir/{filename}"

            # Insert into Trino using parameterized query
            insert_query = """
                INSERT INTO fhir_bundles (file_path, data, ingestion_timestamp)
                VALUES (?, ?, ?)
            """

            cursor.execute(insert_query, (relative_path, fhir_data, ingestion_ts))

            loaded_count += 1
            if loaded_count % 10 == 0:
                print(f"Loaded {loaded_count}/{len(fhir_files)} files...")

        except Exception as e:
            error_count += 1
            print(f"Error loading {filename}: {str(e)}")

    cursor.close()
    conn.close()

    print(f"\n=== Load Summary ===")
    print(f"Successfully loaded: {loaded_count}")
    print(f"Errors: {error_count}")
    print(f"Total files: {len(fhir_files)}")


def verify_data():
    """Verify the loaded data."""
    conn = get_trino_connection()
    cursor = conn.cursor()

    # Count records
    cursor.execute("SELECT COUNT(*) FROM fhir_bundles")
    count = cursor.fetchone()[0]
    print(f"\nTotal records in fhir_bundles: {count}")

    # Show sample
    cursor.execute("SELECT file_path, LENGTH(data) as data_size, ingestion_timestamp FROM fhir_bundles LIMIT 3")
    print("\nSample records:")
    for row in cursor.fetchall():
        print(f"  - {row[0]} | Size: {row[1]} bytes | Ingested: {row[2]}")

    cursor.close()
    conn.close()


if __name__ == "__main__":
    print("=== FHIR Data Loader ===\n")
    load_fhir_files()
    verify_data()
    print("\nDone!")
