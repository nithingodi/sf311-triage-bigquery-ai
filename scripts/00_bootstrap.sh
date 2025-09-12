#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${1:-$(gcloud config get-value project 2>/dev/null)}"
LOCATION="${2:-US}"
DATASET="${3:-sf311}"
BUCKET="${4:-${PROJECT_ID}-data}"
CONN="${5:-us_gemini_conn}"

if [[ -z "${PROJECT_ID}" || "${PROJECT_ID}" == "(unset)" ]]; then
  echo "ERROR: No PROJECT_ID set. Run: gcloud config set project <id> or pass as arg."
  exit 1
fi

echo "== Setup: project & APIs =="
gcloud config set project "$PROJECT_ID" >/dev/null
gcloud services enable bigquery.googleapis.com bigqueryconnection.googleapis.com aiplatform.googleapis.com storage.googleapis.com --project="$PROJECT_ID" >/dev/null

echo "== Ensure dataset ${PROJECT_ID}:${DATASET} =="
if ! bq --project_id="$PROJECT_ID" --location="$LOCATION" ls -d "${PROJECT_ID}:${DATASET}" >/dev/null 2>&1; then
  bq --project_id="$PROJECT_ID" --location="$LOCATION" mk -d "${PROJECT_ID}:${DATASET}"
else
  echo "Dataset exists (ok)."
fi

echo "== Ensure bucket gs://${BUCKET} =="
if ! gcloud storage buckets describe "gs://${BUCKET}" --project="$PROJECT_ID" >/dev/null 2>&1; then
  gcloud storage buckets create "gs://${BUCKET}" --project="$PROJECT_ID" --location="$LOCATION"
else
  echo "Bucket exists (ok)."
fi

echo "== Ensure BigQuery connection ${CONN} =="
if ! bq --project_id="$PROJECT_ID" --location="$LOCATION" show --connection "$CONN" >/dev/null 2>&1; then
  bq --project_id="$PROJECT_ID" --location="$LOCATION" mk --connection --connection_type=CLOUD_RESOURCE "$CONN"
else
  echo "Connection exists (ok)."
fi

GEM_SA=$(bq --project_id="$PROJECT_ID" --location="$LOCATION" show --connection --format=json "$CONN" | jq -r '.cloudResource.serviceAccountId')
echo "Connection SA: ${GEM_SA}"

echo "== Grant aiplatform.user (idempotent) =="
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${GEM_SA}" \
  --role="roles/aiplatform.user" >/dev/null || true

echo "Bootstrap complete."
