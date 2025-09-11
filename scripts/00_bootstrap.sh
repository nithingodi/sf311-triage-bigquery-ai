#!/usr/bin/env bash
set -euo pipefail

# ==========================================================
# 00_bootstrap.sh — provision dataset, bucket, connections, IAM, sanity checks
# ==========================================================

# ---------- Config (env or defaults) ----------
PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null || true)}"
LOCATION="${LOCATION:-US}"
DATASET="${DATASET:-sf311}"
BUCKET_NAME="${BUCKET_NAME:-${PROJECT_ID}-data}"   # unique-ish per project
GEM_CONN_ID="${GEM_CONN_ID:-us_gemini_conn}"
GCS_CONN_ID="${GCS_CONN_ID:-${DATASET}_gcs_conn}"
GEN_ENDPOINT="${GEN_ENDPOINT:-gemini-2.0-flash-001}"

if [[ -z "${PROJECT_ID}" ]]; then
  echo "❌ PROJECT_ID is empty. Set via \`gcloud config set project <id>\` or env."
  exit 1
fi

# ---------- Tools ----------
for t in gcloud bq jq curl; do command -v "$t" >/dev/null || { echo "Missing $t"; exit 1; }; done

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

echo "== BigQuery CLOUD_RESOURCE connections =="
bq --project_id="$PROJECT_ID" --location="$LOCATION" mk --connection \
  --connection_type=CLOUD_RESOURCE --display_name="Gemini" "$GEM_CONN_ID" 2>/dev/null || echo "$GEM_CONN_ID exists"
bq --project_id="$PROJECT_ID" --location="$LOCATION" mk --connection \
  --connection_type=CLOUD_RESOURCE --display_name="GCS" "$GCS_CONN_ID"   2>/dev/null || echo "$GCS_CONN_ID exists"

echo "== Fetch connection service accounts =="
GEM_SA="$(bq --project_id="$PROJECT_ID" --location="$LOCATION" show --connection --format=json "$GEM_CONN_ID" | jq -r '.cloudResource.serviceAccountId')"
GCS_SA="$(bq --project_id="$PROJECT_ID" --location="$LOCATION" show --connection --format=json "$GCS_CONN_ID" | jq -r '.cloudResource.serviceAccountId')"
echo "Gemini SA: ${GEM_SA}"
echo "GCS SA:    ${GCS_SA}"

echo "== Grant IAM to bucket and Vertex AI =="
# Bucket read for GCS connection
gcloud storage buckets add-iam-policy-binding "gs://${BUCKET_NAME}" \
  --member="serviceAccount:${GCS_SA}" --role="roles/storage.objectViewer" >/dev/null || true

# Vertex AI User for Gemini connection SA
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${GEM_SA}" --role="roles/aiplatform.user" >/dev/null || true

# ---- AI.GENERATE: grant to BigQuery agents (project-agnostic) ----
PROJ_NUM="$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')"
BQ_SA="service-${PROJ_NUM}@gcp-sa-bigquery.iam.gserviceaccount.com"
BQ_CONDEL_SA_STD="service-${PROJ_NUM}@gcp-sa-bigquery-condel.iam.gserviceaccount.com"

for SA in "$BQ_SA" "$BQ_CONDEL_SA_STD"; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${SA}" --role="roles/aiplatform.user" >/dev/null || true
done

# Optional: if your org yields a bqcx-* condel SA, allow override via env
if [[ -n "${BQ_BQCX_CONDEL_SA:-}" ]]; then
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${BQ_BQCX_CONDEL_SA}" --role="roles/aiplatform.user" >/dev/null || true
fi

echo "== Minimal normalized view over public SF311 table =="
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
gcloud storage cp -n /dev/null "gs://${BUCKET_NAME}/sf311_cohort/images/.keep" >/dev/null || true
bq --location="$LOCATION" query --use_legacy_sql=false <<SQL
CREATE OR REPLACE EXTERNAL TABLE \`${PROJECT_ID}.${DATASET}.images_obj_cohort\`
WITH CONNECTION \`projects/${PROJECT_ID}/locations/${LOCATION}/connections/${GCS_CONN_ID}\`
OPTIONS (
  object_metadata = 'SIMPLE',
  uris = ['gs://${BUCKET_NAME}/sf311_cohort/images/*']
);
SQL

echo "== Sanity check objects =="
bq --location="$LOCATION" query --use_legacy_sql=false "
SELECT uri, content_type, size
FROM \`${PROJECT_ID}.${DATASET}.images_obj_cohort\`
LIMIT 5;
"

echo "== Optional smoke: upload + summarize image =="
TMP_IMG="/tmp/test_wiki.jpg"
curl -fsSL -o "\$TMP_IMG" "https://upload.wikimedia.org/wikipedia/commons/3/3f/Fronalpstock_big.jpg"
gcloud storage cp --content-type="image/jpeg" "\$TMP_IMG" "gs://${BUCKET_NAME}/sf311_cohort/images/test_wiki.jpg" >/dev/null
bq --location="$LOCATION" query --use_legacy_sql=false "
SELECT
  uri,
  AI.GENERATE(
    (
      'Summarize this SF311 photo in ≤ 15 words. Return only the sentence.',
      OBJ.GET_ACCESS_URL(ref, 'r')
    ),
    connection_id => 'projects/${PROJECT_ID}/locations/${LOCATION}/connections/${GEM_CONN_ID}',
    endpoint      => '${GEN_ENDPOINT}',
    model_params  => JSON '{\"generation_config\":{\"temperature\":0}}'
  ).result AS summary
FROM \`${PROJECT_ID}.${DATASET}.images_obj_cohort\`
WHERE uri = 'gs://${BUCKET_NAME}/sf311_cohort/images/test_wiki.jpg'
LIMIT 1;
"

echo "✅ Bootstrap complete."
