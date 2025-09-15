#!/bin/bash
set -e

# --- Configuration ---
# This script derives all names from the user's gcloud config.
export PROJECT_ID=$(gcloud config get-value project)
export DATASET_ID="sf311"
export LOCATION="US"
export GCS_BUCKET="${PROJECT_ID}-sf311-data" # Globally unique bucket name
export BQ_CONNECTION_ID="sf311-conn"

echo "--- Using Project:    $PROJECT_ID"
echo "--- Using Dataset:    $DATASET_ID"
echo "--- Using GCS Bucket:   gs://$GCS_BUCKET"
echo "--- Using BQ Connection: $BQ_CONNECTION_ID"
echo ""

# --- Resource Creation ---
echo "--> Creating BigQuery Dataset if it doesn't exist..."
bq mk --dataset \
    --location=$LOCATION \
    --project_id=$PROJECT_ID \
    --description="Dataset for SF311 Triage project" \
    $DATASET_ID || echo "Dataset $DATASET_ID already exists."

echo "--> Creating GCS Bucket if it doesn't exist..."
if ! gsutil ls -b "gs://$GCS_BUCKET" >/dev/null 2>&1; then
    gsutil mb -p $PROJECT_ID -l $LOCATION "gs://$GCS_BUCKET"
else
    echo "Bucket gs://$GCS_BUCKET already exists."
fi

echo "--> Creating BigQuery Connection if it doesn't exist..."
if ! bq show --connection --project_id=$PROJECT_ID --location=$LOCATION $BQ_CONNECTION_ID >/dev/null 2>&1; then
    bq mk --connection \
        --location=$LOCATION \
        --project_id=$PROJECT_ID \
        --connection_type=CLOUD_RESOURCE \
        $BQ_CONNECTION_ID
else
    echo "Connection $BQ_CONNECTION_ID already exists."
fi

echo "--- Bootstrap complete ---"
