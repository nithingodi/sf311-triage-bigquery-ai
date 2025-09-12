#!/usr/bin/env bash
# scripts/preprocess.sh
# Usage: ./preprocess.sh path/to/file.sql
# Purpose: Normalize env vars and paths for SQL scripts.

set -euo pipefail

file="$1"
if [[ -z "$file" || ! -f "$file" ]]; then
  echo "Usage: $0 path/to/file.sql" >&2
  exit 2
fi

# --- 1) Replace placeholders with env vars ---
# ${PROJECT_ID}, ${DATASET}, ${LOCATION}, ${CONN}
sed -E \
  -e 's/@PROJECT_ID/${PROJECT_ID}/g' \
  -e 's/@DATASET/${DATASET}/g' \
  -e 's/@LOCATION/${LOCATION}/g' \
  -e 's/@CONN/${CONN}/g' \
  -e 's/@GEM_CONN_ID/${CONN}/g' \
  -e 's/@GEN_ENDPOINT/gemini-2.0-flash-001/g' \
  "$file"
