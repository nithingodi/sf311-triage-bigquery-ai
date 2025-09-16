#!/bin/bash
set -e
PROJECT_ID="sf311-471122"
LOCATION="US"
DATASET_ID="sf311"
BQ_CONNECTION_ID="sf311-conn"
BOOTSTRAP_SCRIPT="scripts/00_bootstrap.sh"
echo "--- Starting Manual Connection Setup ---"
echo "--> Deleting old resources..."
bq rm --force --connection ${PROJECT_ID}.${LOCATION}.${BQ_CONNECTION_ID} || true
bq rm --force --dataset ${PROJECT_ID}:${DATASET_ID} || true
echo "--> Creating new dataset and connection..."
bq mk --dataset --location=$LOCATION ${PROJECT_ID}:${DATASET_ID}
bq mk --connection --location=$LOCATION --project_id=$PROJECT_ID --connection_type=CLOUD_RESOURCE $BQ_CONNECTION_ID
echo "--> Waiting 60 seconds for initialization..."
sleep 60
echo "--> Fetching Service Account ID..."
SERVICE_ACCOUNT_ID=$(bq show --connection --format=json ${PROJECT_ID}.${LOCATION}.${BQ_CONNECTION_ID} | jq -r .serviceAccountId)
if [[ -z "$SERVICE_ACCOUNT_ID" || "$SERVICE_ACCOUNT_ID" == "null" ]]; then
    echo "🚨 ERROR: Service Account ID could not be found." && exit 1
fi
echo "    Found Service Account: $SERVICE_ACCOUNT_ID"
echo "--> Automatically configuring the main bootstrap script..."
sed -i "s|SERVICE_ACCOUNT_ID=\"--PLACEHOLDER--\"|SERVICE_ACCOUNT_ID=\"${SERVICE_ACCOUNT_ID}\"|g" "$BOOTSTRAP_SCRIPT"
echo "--> Granting permissions to the new Service Account..."
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$SERVICE_ACCOUNT_ID" --role="roles/aiplatform.user"
echo "✅ Manual setup complete. You can now run 'make run_all'."
