#!/usr/bin/env bash
# scripts/preprocess.sh
set -euo pipefail

file="$1"
if [[ -z "$file" || ! -f "$file" ]]; then
  echo "Usage: $0 path/to/file.sql" >&2
  exit 2
fi

# 1) Normalize @PROJECT_ID -> ${PROJECT_ID}
# 2) Convert projects/%s/locations/%s/connections/%s -> projects/${PROJECT_ID}/locations/${LOCATION}/connections/${CONN}
# 3) Convert `%s.%s` -> `${PROJECT_ID}.${DATASET}`
# 4) Normalize DECLARE lines that used "@PROJECT_ID" etc.
sed -E \
  -e 's/@PROJECT_ID/${PROJECT_ID}/g' \
  -e 's/projects\/%s\/locations\/%s\/connections\/%s/projects\/${PROJECT_ID}\/locations\/${LOCATION}\/connections\/${CONN}/g' \
  -e 's/`%s\.%s\.([A-Za-z0-9_]+)`/`${PROJECT_ID}.${DATASET}.\1`/g' \
  -e 's/`%s\.%s`/`${PROJECT_ID}.${DATASET}`/g' \
  -e 's/%s\.%s/${PROJECT_ID}.${DATASET}/g' \
  -e 's/DECLARE[[:space:]]+project_id[[:space:]]+STRING[[:space:]]+DEFAULT[[:space:]]+".*"/DECLARE project_id STRING DEFAULT '\''${PROJECT_ID}'\''/g' \
  -e 's/DECLARE[[:space:]]+dataset[[:space:]]+STRING[[:space:]]+DEFAULT[[:space:]]+".*"/DECLARE dataset STRING DEFAULT '\''${DATASET}'\''/g' \
  "$file"
