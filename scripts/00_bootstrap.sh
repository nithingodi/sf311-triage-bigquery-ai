#!/usr/bin/env bash
set -euo pipefail

# ==========================================================
# Project: City311 Multimodal Triage with BigQuery AI
# Script: 00_bootstrap.sh
# Purpose: Provision GCP primitives used by the SQL-only pipeline:
#          - BigQuery dataset
#          - GCS bucket
#          - BigQuery connections (Gemini & GCS)
#          - Minimal view + External Object Table
#          - Sanity smoke run with AI.GENERATE
# Idempotency: Safe to re-run; will no-op when resources exist.
# Prereqs:
#   - gcloud, bq, jq, curl installed
#   - gcloud auth login (or a configured service account)
#   - Billing enabled on the project
# ==========================================================

# ====== EDIT ME (or export as env vars before running) ======
PROJECT_ID="${PROJECT_ID:-sf311-triage-2025}"
LOCATION="${LOCATION:-US}"                  # Keep 'US' for SF311 (multi-region)
DATASET="${DATASET:-sf311}"
BUCKET_NAME="${BUCKET_NAME:-sf311-triage-2025-data}"   # Must be globally unique
GEM_CONN_ID="${GEM_CONN_ID:-us_gemini_conn}"
GCS_CONN_ID="${GCS_CONN_ID:-sf311_gcs_conn}"
GEM_MODEL_ENDPOINT="${GEM_MODEL_ENDPOINT:-gemini-2.0-flash-001}"
# ============================================================

# ---- Preflight checks ----
command -v gcloud >/dev/null || { echo "gcloud not found"; exit 1; }
command -v bq >/dev/null     || { echo "bq not found"; exit 1; }
command -v jq >/dev/null     || { echo "jq not found"; exit 1; }
command -v curl >/dev/null   || { echo "curl not found"; exit 1; }

echo "== Setup: project & APIs =="
gcloud config set project "$PROJECT_ID" >/dev/null
gcloud services enable \
  bigquery.googleapis.com \
  aiplatform.googleapis.com \
  bigqueryconnection.googleapis.com \
  storage.googleapis.com

echo "== Dataset (${PROJECT_ID}:${DATASET}) =="
bq --location="$LOCATION" mk --dataset --description "SF311 triage prototype" "${PROJECT_ID}:${DATASET}" \
  2>/dev/null || echo "Dataset exists"

echo "== GCS bucket (gs://${BUCKET_NAME}) =="
gcloud storage buckets create "gs://${BUCKET_NAME}" \
  --location="${LOCATION}" \
  --uniform-bucket-level-access \
  2>/dev/null || echo "Bucket exists"

echo "== BigQuery connections (CLOUD_RESOURCE) =="
# Connection IDs are simple tokens; project/location given via flags
bq --project_id="$PROJECT_ID" --location="$LOCATION" mk --connection \
  --connection_type=CLOUD_RESOURCE --display_name="Gemini" "$GEM_CONN_ID" \
  2>/dev/null || echo "$GEM_CONN_ID exists"

bq --project_id="$PROJECT_ID" --location="$LOCATION" mk --connection \
  --connection_type=CLOUD_RESOURCE --display_name="GCS" "$GCS_CONN_ID" \
  2>/dev/null || echo "$GCS_CONN_ID exists"

echo "== Fetch connection service accounts =="
GEM_SA="$(bq --project_id="$PROJECT_ID" --location="$LOCATION" show --connection --format=json "$GEM_CONN_ID" | jq -r '.cloudResource.serviceAccountId')"
GCS_SA="$(bq --project_id="$PROJECT_ID" --location="$LOCATION" show --connection --format=json "$GCS_CONN_ID" | jq -r '.cloudResource.serviceAccountId')"
echo "Gemini SA: ${GEM_SA}"
echo "GCS SA:    ${GCS_SA}"

echo "== Grant IAM =="
# Allow BigQuery (via GCS connection) to read bucket objects
gcloud storage buckets add-iam-policy-binding "gs://${BUCKET_NAME}" \
  --member="serviceAccount:${GCS_SA}" \
  --role="roles/storage.objectViewer" \
  >/dev/null || true

# Allow Gemini connection to call Vertex AI
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${GEM_SA}" \
  --role="roles/aiplatform.user" \
  >/dev/null || true

echo "== Minimal normalized view over the public SF311 table =="
bq --location="$LOCATION" query --use_legacy_sql=false "
CREATE OR REPLACE VIEW \`${PROJECT_ID}.${DATASET}.cases_norm\` AS
SELECT
  CAST(unique_key AS STRING)                         AS service_request_id,
  created_date                                       AS requested_datetime,
  COALESCE(complaint_type, category)                 AS request_type,
  COALESCE(descriptor, status_notes, complaint_type) AS request_details,
  agency_name                                        AS agency_responsible,
  media_url
FROM \`bigquery-public-data.san_francisco_311.311_service_requests\`;
"

echo "== External Object Table over images prefix =="
# Ensure the prefix exists (OK if empty)
gcloud storage cp -n /dev/null "gs://${BUCKET_NAME}/sf311_cohort/images/.keep" >/dev/null || true

# Create/replace the external object table (fixed missing backtick)
bq --location="$LOCATION" query --use_legacy_sql=false <<SQL
CREATE OR REPLACE EXTERNAL TABLE \`${PROJECT_ID}.${DATASET}.images_obj_cohort\`
WITH CONNECTION \`projects/${PROJECT_ID}/locations/${LOCATION}/connections/${GCS_CONN_ID}\`
OPTIONS (
  object_metadata = 'SIMPLE',
  uris = ['gs://${BUCKET_NAME}/sf311_cohort/images/*']
);
SQL

echo "== Sanity check: list a few objects (may be empty except .keep) =="
bq --location="$LOCATION" query --use_legacy_sql=false "
SELECT uri, content_type, size
FROM \`${PROJECT_ID}.${DATASET}.images_obj_cohort\`
LIMIT 5;
"

echo "== Optional smoke: upload one real image & summarize with AI.GENERATE =="
TMP_IMG="/tmp/test_wiki.jpg"
curl -fsSL -o "\$TMP_IMG" "https://upload.wikimedia.org/wikipedia/commons/3/3f/Fronalpstock_big.jpg"
gcloud storage cp --content-type="image/jpeg" "\$TMP_IMG" "gs://${BUCKET_NAME}/sf311_cohort/images/test_wiki.jpg" >/dev/null

bq --location="$LOCATION" query --use_legacy_sql=false "
SELECT
  uri,
  AI.GENERATE(
    (
      'Summarize this SF311 photo in \u2264 15 words. Return only the sentence.',
      OBJ.GET_ACCESS_URL(ref, 'r')
    ),
    connection_id => 'projects/${PROJECT_ID}/locations/${LOCATION}/connections/${GEM_CONN_ID}',
    endpoint      => '${GEM_MODEL_ENDPOINT}',
    model_params  => JSON '{\"generation_config\":{\"temperature\":0}}'
  ).result AS summary
FROM \`${PROJECT_ID}.${DATASET}.images_obj_cohort\`
WHERE uri = 'gs://${BUCKET_NAME}/sf311_cohort/images/test_wiki.jpg'
LIMIT 1;
"

echo "✅ Bootstrap complete."
