#!/bin/bash
set -e

# --- Configuration ---
export PROJECT_ID=$(gcloud config get-value project)
export DATASET_ID="sf311"
export LOCATION="US"
export GCS_BUCKET="${PROJECT_ID}-sf311-data"
export BQ_CONNECTION_ID="sf311-conn"

echo "--- 🛠️  Starting Automated Bootstrap for Project: $PROJECT_ID ---"

# --- Step 1: Clean up previous resources ---
echo "--> Cleaning up old resources (if they exist)..."
bq rm -f --dataset --recursive=true "${PROJECT_ID}:${DATASET_ID}" || true
gsutil -m rm -r "gs://${GCS_BUCKET}" || true
bq rm -f --connection "${PROJECT_ID}.${LOCATION}.${BQ_CONNECTION_ID}" || true

# --- Step 2: Enable Required APIs ---
echo "--> Enabling required APIs..."
gcloud services enable aiplatform.googleapis.com \
                       bigqueryconnection.googleapis.com \
                       --project=$PROJECT_ID

# --- Step 3: Create Resources ---
echo "--> Creating new resources..."
bq mk --dataset --location=$LOCATION "${PROJECT_ID}:${DATASET_ID}"
gsutil mb -p $PROJECT_ID -l $LOCATION "gs://$GCS_BUCKET"
bq mk --connection --location=$LOCATION --project_id=$PROJECT_ID --connection_type=CLOUD_RESOURCE $BQ_CONNECTION_ID
echo "    Connection created. Waiting 60 seconds for initialization..."
sleep 60

# --- Step 4: Fetch Service Account and Grant Permissions ---
echo "--> Fetching Service Account and granting permissions..."
RETRY_COUNT=0
MAX_RETRIES=5
DELAY=5
SERVICE_ACCOUNT_ID=""
while [ -z "$SERVICE_ACCOUNT_ID" ] || [ "$SERVICE_ACCOUNT_ID" == "null" ]; do
    SERVICE_ACCOUNT_ID=$(bq show --connection --format=json ${PROJECT_ID}.${LOCATION}.${BQ_CONNECTION_ID} | jq -r .serviceAccountId)
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -gt $MAX_RETRIES ]; then
        echo "    🚨 Could not find Service Account ID after 5 attempts. This is likely an Organization Policy issue."
        exit 1
    fi
    if [ -z "$SERVICE_ACCOUNT_ID" ] || [ "$SERVICE_ACCOUNT_ID" == "null" ]; then
        echo "    Service account not found yet, retrying in 5 seconds... (Attempt $RETRY_COUNT/$MAX_RETRIES)"
        sleep $DELAY
    fi
done
echo "    Found Service Account: $SERVICE_ACCOUNT_ID"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_ID" \
    --role="roles/aiplatform.user" \
    --condition=None > /dev/null
echo "    Permissions granted successfully."
echo ""
echo "--- ✅ Automated Bootstrap complete ---"
