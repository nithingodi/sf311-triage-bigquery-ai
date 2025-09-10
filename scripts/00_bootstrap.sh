#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-sf311-triage-2025}"
DATASET="${DATASET:-sf311}"
LOCATION="${LOCATION:-US}"
GEM_CONN_ID="${GEM_CONN_ID:-us_gemini_conn}"

echo "Project:  $PROJECT_ID"
echo "Dataset:  $DATASET"
echo "Location: $LOCATION"

# Create dataset (idempotent)
bq --project_id="$PROJECT_ID" --location="$LOCATION" mk -d "$DATASET" || true

# Create Gemini connection if missing
if ! bq --project_id="$PROJECT_ID" --location="$LOCATION" show --connection "$GEM_CONN_ID" >/dev/null 2>&1; then
  bq --project_id="$PROJECT_ID" --location="$LOCATION" mk --connection \
     --display_name="Gemini Connection" --connection_type=CLOUD_RESOURCE "$GEM_CONN_ID"
fi

# Grant AI Platform role to the connection service account
GEM_SA=$(bq --project_id="$PROJECT_ID" --location="$LOCATION" show --connection --format=json "$GEM_CONN_ID" | jq -r '.cloudResource.serviceAccountId')
echo "Gemini connection SA: ${GEM_SA}"
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${GEM_SA}" --role="roles/aiplatform.user" >/dev/null

echo "Bootstrap complete."
