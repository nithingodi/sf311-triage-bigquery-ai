#!/usr/bin/env bash
set -euo pipefail

# ========= Config =========
PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null || true)}"
LOCATION="${LOCATION:-US}"               # BigQuery region
DATASET="${DATASET:-sf311}"
BUCKET="${BUCKET:-${PROJECT_ID}-data}"   # gs://<project>-data
GEM_CONN_ID="${GEM_CONN_ID:-us_gemini_conn}"
GCS_CONN_ID="${GCS_CONN_ID:-sf311_gcs_conn}"
# ==========================

if [[ -z "${PROJECT_ID}" ]]; then
  echo "ERROR: PROJECT_ID not set. Run: gcloud config set project <ID> or pass PROJECT_ID=..."
  exit 1
fi

echo "== Setup: project & APIs =="
gcloud config set project "${PROJECT_ID}" >/dev/null
gcloud services enable bigquery.googleapis.com aiplatform.googleapis.com storage.googleapis.com --quiet

echo "== Dataset (${PROJECT_ID}:${DATASET}) =="
bq --location="${LOCATION}" mk --dataset --default_table_expiration 0 --default_partition_expiration 0 \
  --description "SF311 demo dataset" "${PROJECT_ID}:${DATASET}" 2>/dev/null || echo "(skip) dataset exists"

echo "== GCS bucket (gs://${BUCKET}) =="
gcloud storage buckets create "gs://${BUCKET}" --project="${PROJECT_ID}" --location="${LOCATION}" 2>/dev/null || echo "(skip) bucket exists"

echo "== BigQuery CLOUD_RESOURCE connections =="
# Gemini
if ! bq --project_id="${PROJECT_ID}" --location="${LOCATION}" show --connection "${GEM_CONN_ID}" >/dev/null 2>&1; then
  bq --project_id="${PROJECT_ID}" --location="${LOCATION}" mk --connection \
    --connection_type=CLOUD_RESOURCE "${GEM_CONN_ID}"
  echo "Created ${GEM_CONN_ID}"
else
  echo "(skip) ${GEM_CONN_ID} exists"
fi
# GCS
if ! bq --project_id="${PROJECT_ID}" --location="${LOCATION}" show --connection "${GCS_CONN_ID}" >/dev/null 2>&1; then
  bq --project_id="${PROJECT_ID}" --location="${LOCATION}" mk --connection \
    --connection_type=CLOUD_RESOURCE "${GCS_CONN_ID}"
  echo "Created ${GCS_CONN_ID}"
else
  echo "(skip) ${GCS_CONN_ID} exists"
fi

echo "== Fetch connection service accounts =="
# no jq dependency; use sed
GEM_SA="$(bq --project_id="${PROJECT_ID}" --location="${LOCATION}" show --connection --format=json "${GEM_CONN_ID}" \
          | sed -n 's/.*"serviceAccountId"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
GCS_SA="$(bq --project_id="${PROJECT_ID}" --location="${LOCATION}" show --connection --format=json "${GCS_CONN_ID}" \
          | sed -n 's/.*"serviceAccountId"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"

echo "Gemini SA: ${GEM_SA}"
echo "GCS SA   : ${GCS_SA}"

if [[ -z "${GEM_SA}" || -z "${GCS_SA}" ]]; then
  echo "ERROR: Could not resolve connection service accounts. Aborting."
  exit 1
fi

echo "== Grant IAM to connection SAs (roles/aiplatform.user) =="
for SA in "${GEM_SA}" "${GCS_SA}"; do
  echo "Granting roles/aiplatform.user to ${SA}"
  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${SA}" \
    --role="roles/aiplatform.user" --quiet >/dev/null 2>&1 || true
done

echo "== Seed folders & test artifacts in GCS =="
mkdir -p /tmp/sf311 && touch /tmp/sf311/.keep
gcloud storage cp /tmp/sf311/.keep "gs://${BUCKET}/sf311_cohort/images/.keep" >/dev/null 2>&1 || true

# tiny public test image
TEST_IMG="/tmp/test_wiki.jpg"
if [[ ! -s "${TEST_IMG}" ]]; then
  curl -L -o "${TEST_IMG}" "https://upload.wikimedia.org/wikipedia/commons/3/3f/Fronalpstock_big.jpg" >/dev/null 2>&1 || true
fi
gcloud storage cp "${TEST_IMG}" "gs://${BUCKET}/sf311_cohort/images/test_wiki.jpg" >/dev/null 2>&1 || true

echo "== Sanity: AI.GENERATE_TEXT permission check =="
bq query --nouse_legacy_sql --location="${LOCATION}" --project_id="${PROJECT_ID}" \
"SELECT AI.GENERATE_TEXT(STRUCT('gemini-2.0-flash-001' AS model, 'hello' AS prompt))" >/dev/null \
  && echo "(ok) AI.GENERATE_TEXT runnable" \
  || echo "(warn) AI.GENERATE_TEXT not runnable yet — recheck IAM/APIs"

echo "Bootstrap complete."
