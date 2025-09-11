#!/usr/bin/env bash
set -euo pipefail

# ========= Config =========
PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null || true)}"
LOCATION="${LOCATION:-US}"
DATASET="${DATASET:-sf311}"
BUCKET="${BUCKET:-${PROJECT_ID}-data}"
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
bq --location="${LOCATION}" mk --dataset "${PROJECT_ID}:${DATASET}" 2>/dev/null || echo "(skip) dataset exists"

echo "== GCS bucket (gs://${BUCKET}) =="
gcloud storage buckets create "gs://${BUCKET}" --project="${PROJECT_ID}" --location="${LOCATION}" 2>/dev/null || echo "(skip) bucket exists"

echo "== BigQuery CLOUD_RESOURCE connections =="
for CONN in "${GEM_CONN_ID}" "${GCS_CONN_ID}"; do
  if ! bq --project_id="${PROJECT_ID}" --location="${LOCATION}" show --connection "${CONN}" >/dev/null 2>&1; then
    bq --project_id="${PROJECT_ID}" --location="${LOCATION}" mk --connection --connection_type=CLOUD_RESOURCE "${CONN}"
    echo "Created ${CONN}"
  else
    echo "(skip) ${CONN} exists"
  fi
done

echo "== Fetch connection service accounts & grant IAM =="
for CONN in "${GEM_CONN_ID}" "${GCS_CONN_ID}"; do
  SA="$(bq --project_id="${PROJECT_ID}" --location="${LOCATION}" show --connection --format=json "${CONN}" \
        | sed -n 's/.*"serviceAccountId"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
  echo "${CONN} SA: ${SA}"
  if [[ -n "${SA}" ]]; then
    gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
      --member="serviceAccount:${SA}" \
      --role="roles/aiplatform.user" --quiet >/dev/null 2>&1 || true
  else
    echo "WARN: could not resolve service account for ${CONN}"
  fi
done

echo "== Seed small test image =="
mkdir -p /tmp/sf311 && touch /tmp/sf311/.keep
gcloud storage cp /tmp/sf311/.keep "gs://${BUCKET}/sf311_cohort/images/.keep" >/dev/null 2>&1 || true
curl -L -o /tmp/test_wiki.jpg "https://upload.wikimedia.org/wikipedia/commons/3/3f/Fronalpstock_big.jpg" >/dev/null 2>&1 || true
gcloud storage cp /tmp/test_wiki.jpg "gs://${BUCKET}/sf311_cohort/images/test_wiki.jpg" >/dev/null 2>&1 || true

echo "== Sanity: AI.GENERATE_TEXT permission check =="
bq query --nouse_legacy_sql --location="${LOCATION}" --project_id="${PROJECT_ID}" \
"SELECT AI.GENERATE_TEXT(STRUCT('gemini-2.0-flash-001' AS model, 'hello' AS prompt))" >/dev/null \
  && echo "(ok) AI.GENERATE_TEXT runnable" \
  || echo "(warn) AI.GENERATE_TEXT not runnable yet — recheck IAM/APIs"

echo "Bootstrap complete."
