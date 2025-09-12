#!/usr/bin/env bash
# scripts/preprocess.sh
# Usage: PREPROCESS env vars must be set (PROJECT_ID, DATASET, LOCATION, CONN).
#         ./scripts/preprocess.sh path/to/file.sql
set -euo pipefail

file="${1:-}"

if [[ -z "$file" || ! -f "$file" ]]; then
  echo "Usage: $0 path/to/file.sql" >&2
  exit 2
fi

# We intentionally produce ${PROJECT_ID} etc. literals so envsubst can expand them
# in a later step. Avoid directly expanding with sed to keep consistent substitution.

sed -E \
  -e 's/@PROJECT_ID/${PROJECT_ID}/g' \
  -e 's/projects\/%s\/locations\/%s\/connections\/%s/projects\/${PROJECT_ID}\/locations\/${LOCATION}\/connections\/${CONN}/g' \
  -e 's/%s\.%s/${PROJECT_ID}.${DATASET}/g' \
  -e 's/`%s\.%s\.([a-zA-Z0-9_]+)`/`${PROJECT_ID}.${DATASET}.\1`/g' \
  -e 's/`%s\.%s\.([a-zA-Z0-9_]+)\.([a-zA-Z0-9_]+)`/`${PROJECT_ID}.${DATASET}.\1.\2`/g' \
  -e 's/DECLARE[[:space:]]+project_id[[:space:]]+STRING[[:space:]]+DEFAULT[[:space:]]+".*"/DECLARE project_id STRING DEFAULT '\''${PROJECT_ID}'\'';/' \
  -e 's/DECLARE[[:space:]]+dataset[[:space:]]+STRING[[:space:]]+DEFAULT[[:space:]]+".*"/DECLARE dataset STRING DEFAULT '\''${DATASET}'\'';/' \
  "$file"
