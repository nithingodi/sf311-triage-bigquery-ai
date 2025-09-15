#!/bin/bash
set -e

# --- Configuration ---
PROJECT_ID="sf311-471122"
LOCATION="US"
DATASET_ID="sf311"
BQ_CONNECTION_ID="sf311-conn"
BOOTSTRAP_SCRIPT="scripts/00_bootstrap.sh"

echo "--- Starting Manual Connection Setup ---"

# 1. Clean up old resources to ensure a fresh start.
echo "--> Deleting old resources (if they exist)..."
bq rm --force --connection ${PROJECT_ID}.${LOCATION}.${BQ_CONNECTION_ID} || true
bq rm --force --dataset ${PROJECT_ID}:${DATASET_ID} || true

# 2. Create the dataset and connection.
echo "--> Creating new dataset and connection..."
bq mk --dataset --location=$LOCATION ${PROJECT_ID}:${DATASET_ID}
bq mk --connection --location=$LOCATION --connection_type=CLOUD_RESOURCE ${PROJECT_ID}.${LOCATION}.${BQ_CONNECTION_ID}

# 3. Wait for the connection to be fully provisioned.
echo "--> Waiting 60 seconds for initialization..."
sleep 60

# 4. Fetch the new service account ID.
echo "--> Fetching Service Account ID..."
SERVICE_ACCOUNT_ID=$(bq show --connection --format=json ${PROJECT_ID}.${LOCATION}.${BQ_CONNECTION_ID} | jq -r .serviceAccountId)

if [[ -z "$SERVICE_ACCOUNT_ID" || "$SERVICE_ACCOUNT_ID" == "null" ]]; then
    echo "🚨 ERROR: Service Account ID could not be found. Please check your project's Organization Policies."
    exit 1
fi
echo "    Found Service Account: $SERVICE_ACCOUNT_ID"

# 5. Automatically insert the Service Account ID into the main bootstrap script.
echo "--> Automatically configuring the main bootstrap script..."
sed -i "s|SERVICE_ACCOUNT_ID=\"--PLACEHOLDER--\"|SERVICE_ACCOUNT_ID=\"${SERVICE_ACCOUNT_ID}\"|g" "$BOOTSTRAP_SCRIPT"

# 6. Grant the necessary permissions to the new service account.
echo "--> Granting permissions to the new Service Account..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_ID" \
    --role="roles/aiplatform.user"

echo "✅ Manual setup complete. You can now run 'make run_all'."
