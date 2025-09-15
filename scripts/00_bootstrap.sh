#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration ---
export PROJECT_ID=$(gcloud config get-value project)
export DATASET_ID="sf311"
export LOCATION="US"
export GCS_BUCKET="${PROJECT_ID}-sf311-data"
export BQ_CONNECTION_ID="sf311-conn"

echo "--- 🛠️  Starting Bootstrap for Project: $PROJECT_ID ---"
echo ""

# --- Step 1: Enable Required Google Cloud APIs ---
echo "--> Enabling required APIs (Vertex AI & BigQuery Connection)..."
gcloud services enable aiplatform.googleapis.com \
                       bigqueryconnection.googleapis.com \
                       --project=$PROJECT_ID

# --- Step 2: Create BigQuery Dataset ---
echo "--> Creating BigQuery Dataset '$DATASET_ID' (if needed)..."
bq mk --dataset \
    --location=$LOCATION \
    --project_id=$PROJECT_ID \
    --description="Dataset for SF311 Triage project" \
    $DATASET_ID || echo "    Dataset '$DATASET_ID' already exists."

# --- Step 3: Create GCS Bucket ---
echo "--> Creating GCS Bucket 'gs://$GCS_BUCKET' (if needed)..."
if ! gsutil ls -b "gs://$GCS_BUCKET" >/dev/null 2>&1; then
    gsutil mb -p $PROJECT_ID -l $LOCATION "gs://$GCS_BUCKET"
else
    echo "    Bucket 'gs://$GCS_BUCKET' already exists."
fi

# --- Step 4: Create BigQuery Connection ---
echo "--> Creating BigQuery Connection '$BQ_CONNECTION_ID' (if needed)..."
if ! bq show --connection --project_id=$PROJECT_ID --location=$LOCATION $BQ_CONNECTION_ID >/dev/null 2>&1; then
    bq mk --connection \
        --location=$LOCATION \
        --project_id=$PROJECT_ID \
        --connection_type=CLOUD_RESOURCE \
        $BQ_CONNECTION_ID
else
    echo "    Connection '$BQ_CONNECTION_ID' already exists."
fi

# --- Step 5: Grant IAM Permissions to the Connection's Service Account ---
echo "--> Granting 'Vertex AI User' role to the connection's service account..."

# Get the service account ID using the reliable JSON output format and jq parser.
SERVICE_ACCOUNT_ID=$(bq show --connection --project_id=$PROJECT_ID --location=US --format=json $BQ_CONNECTION_ID | jq -r .serviceAccountId)

if [ -z "$SERVICE_ACCOUNT_ID" ] || [ "$SERVICE_ACCOUNT_ID" == "null" ]; then
    echo "    🚨 Could not find Service Account ID for connection. Exiting."
    exit 1
fi

echo "    Found Service Account: $SERVICE_ACCOUNT_ID"

# Grant the required IAM role.
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_ID" \
    --role="roles/aiplatform.user" \
    --condition=None > /dev/null # Hide verbose output

echo "    Permissions granted successfully."
echo ""
echo "--- ✅ Bootstrap complete ---"
