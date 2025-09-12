#!/usr/bin/env bash
# Robust bootstrap for sf311 project.
# Usage:
#   ./bootstrap.sh [PROJECT_ID] [LOCATION] [DATASET] [BUCKET] [CONN]
set -euo pipefail

# ---------- Defaults (positional args, fall back to gcloud config)
PROJECT_ID="${1:-$(gcloud config get-value project 2>/dev/null || true)}"
LOCATION="${2:-US}"
DATASET="${3:-sf311}"
BUCKET="${4:-${PROJECT_ID}-data}"
CONN="${5:-us_gemini_conn}"

# ---------- Helpers
info(){ printf "\033[1;34m==> %s\033[0m\n" "$*"; }
warn(){ printf "\033[1;33mWARN: %s\033[0m\n" "$*"; }
err(){ printf "\033[1;31mERR: %s\033[0m\n" "$*"; }

# ---------- Pre-flight checks
command -v gcloud >/dev/null 2>&1 || { err "gcloud not found; install Google Cloud SDK"; exit 1; }
command -v bq >/dev/null 2>&1 || { err "bq (BigQuery CLI) not found; install/enable Cloud SDK component 'bq'"; exit 1; }

# jq is optional but strongly recommended
if ! command -v jq >/dev/null 2>&1; then
  warn "jq not found. JSON parsing will be limited; please install jq for better diagnostics."
  USE_JQ=false
else
  USE_JQ=true
fi

# Validate PROJECT_ID
if [[ -z "${PROJECT_ID:-}" || "${PROJECT_ID}" == "(unset)" ]]; then
  err "No PROJECT_ID set. Run: gcloud config set project <id> OR pass as first arg to this script."
  exit 1
fi

info "Using PROJECT_ID=${PROJECT_ID} LOCATION=${LOCATION} DATASET=${DATASET} BUCKET=${BUCKET} CONN=${CONN}"

# Set project in gcloud explicitly (prints nothing on success)
info "Setting gcloud project to ${PROJECT_ID}"
gcloud config set project "${PROJECT_ID}"

# Enable APIs (show output to help debugging)
info "Enabling required APIs for project ${PROJECT_ID} (this may take a moment)"
gcloud services enable \
  bigquery.googleapis.com \
  bigqueryconnection.googleapis.com \
  aiplatform.googleapis.com \
  storage.googleapis.com \
  --project="${PROJECT_ID}"

# ---------- Ensure dataset exists
info "Ensure dataset ${PROJECT_ID}:${DATASET}"
if ! bq --project_id="${PROJECT_ID}" --location="${LOCATION}" show --dataset "${PROJECT_ID}:${DATASET}" >/dev/null 2>&1; then
  info "Dataset not found; creating ${PROJECT_ID}:${DATASET}"
  bq --project_id="${PROJECT_ID}" --location="${LOCATION}" mk --dataset --description "sf311 dataset" "${PROJECT_ID}:${DATASET}"
else
  info "Dataset exists (ok)."
fi

# ---------- Ensure bucket exists (be careful: bucket names are global)
info "Ensure bucket gs://${BUCKET}"
if ! gcloud storage buckets describe "gs://${BUCKET}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  info "Creating bucket gs://${BUCKET} in ${LOCATION}"
  # Note: bucket names are global; creation will fail if name already taken elsewhere.
  if gcloud storage buckets create "gs://${BUCKET}" --project="${PROJECT_ID}" --location="${LOCATION}" ; then
    info "Bucket created."
  else
    err "Failed to create bucket gs://${BUCKET}. Bucket names are global — it may already exist. Choose a unique name and re-run."
    exit 1
  fi
else
  info "Bucket exists (ok)."
fi

# ---------- Ensure BigQuery connection exists (best-effort)
info "Ensure BigQuery connection ${CONN}"
if ! bq --project_id="${PROJECT_ID}" --location="${LOCATION}" show --connection "${CONN}" >/dev/null 2>&1; then
  info "Connection ${CONN} not found. Attempting to create a CLOUD_RESOURCE connection (best-effort)."
  set +e
  bq --project_id="${PROJECT_ID}" --location="${LOCATION}" mk --connection --connection_type=CLOUD_RESOURCE "${CONN}"
  RC=$?
  set -e
  if [[ $RC -ne 0 ]]; then
    warn "Automatic creation of the connection failed. This can require additional properties or manual configuration in the Console."
    warn "You can create the connection in the Console or run a more specific bq mk --connection ... command with required --properties."
  else
    info "Connection created (ok)."
  fi
else
  info "Connection exists (ok)."
fi

# ---------- Extract connection service account (if present)
GEM_SA=""
if $USE_JQ ; then
  info "Querying connection JSON to obtain cloudResource.serviceAccountId"
  # bq show --connection --format=json returns detailed connection metadata
  CON_JSON=$(bq --project_id="${PROJECT_ID}" --location="${LOCATION}" show --connection --format=json "${CONN}" 2>/dev/null || true)
  if [[ -n "${CON_JSON}" ]]; then
    GEM_SA=$(printf "%s" "${CON_JSON}" | jq -r '.cloudResource.serviceAccountId // empty')
  fi
else
  info "jq not available; attempting to parse minimal output for service account (fragile)"
  # try to find a service account string in 'bq show' output (very fragile)
  GEM_SA=$(bq --project_id="${PROJECT_ID}" --location="${LOCATION}" show --connection "${CONN}" 2>/dev/null | grep -Eo 'serviceAccount:[^ ]+' | head -n1 || true)
  GEM_SA=${GEM_SA#serviceAccount:}
fi

if [[ -z "${GEM_SA}" ]]; then
  warn "Could not determine connection service account (GEM_SA). Skipping IAM binding. If you expect a Cloud Resource connection, check the connection properties in the Console."
else
  info "Connection SA: ${GEM_SA}"
  info "Granting roles/aiplatform.user to ${GEM_SA} (idempotent)"
  # Use add-iam-policy-binding (will no-op if already set); show results for visibility
  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${GEM_SA}" \
    --role="roles/aiplatform.user"
fi

info "Bootstrap complete."
