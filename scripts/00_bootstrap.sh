#!/bin/bash
set -e
export PROJECT_ID=$(gcloud config get-value project)
export DATASET_ID="sf311"
export LOCATION="US"
export GCS_BUCKET="${PROJECT_ID}-sf311-data"
export BQ_CONNECTION_ID="sf311-conn"
echo "--- 🛠️  Starting Bootstrap for Project: $PROJECT_ID ---"
echo "--> Enabling required APIs..."
gcloud services enable aiplatform.googleapis.com bigqueryconnection.googleapis.com --project=$PROJECT_ID
echo "--> Verifying GCS Bucket 'gs://$GCS_BUCKET'..."
if ! gsutil ls -b "gs://$GCS_BUCKET" >/dev/null 2>&1; then
    gsutil mb -p $PROJECT_ID -l $LOCATION "gs://$GCS_BUCKET"
else
    echo "    Bucket found."
fi
echo "--> Verifying BigQuery Connection '$BQ_CONNECTION_ID'..."
if ! bq show --connection --project_id=$PROJECT_ID --location=$LOCATION $BQ_CONNECTION_ID >/dev/null 2>&1; then
    echo "    🚨 ERROR: Connection not found. Please run 'bash scripts/manual_setup.sh' first." && exit 1
else
    echo "    Connection found."
fi
echo "--> Granting 'Vertex AI User' role..."
SERVICE_ACCOUNT_ID="--PLACEHOLDER--"
if [[ "$SERVICE_ACCOUNT_ID" == "--PLACEHOLDER--" ]]; then
    echo "    🚨 ERROR: Service Account ID is not set. Please run 'bash scripts/manual_setup.sh' first." && exit 1
fi
echo "    Using Service Account: $SERVICE_ACCOUNT_ID"
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$SERVICE_ACCOUNT_ID" --role="roles/aiplatform.user" --condition=None > /dev/null
echo "    Permissions granted successfully."
echo "--- ✅ Bootstrap complete ---"
