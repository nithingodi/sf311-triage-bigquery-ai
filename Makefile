# Makefile

# Automatically get the currently configured GCP Project ID
PROJECT_ID := $(shell gcloud config get-value project)

# --- Centralized Configuration ---
DATASET_ID := sf311
LOCATION := US
BQ_CONNECTION_ID := sf311-conn

# --- Main Targets ---
.PHONY: run_all
run_all: bootstrap models views # Add other SQL targets here as needed
	@echo "\n✅ All steps completed successfully!"

.PHONY: bootstrap
bootstrap:
	@echo "--- 1. Bootstrapping all GCP Resources ---"
	@bash scripts/00_bootstrap.sh

# --- SQL Execution Helper ---
define RUN_SQL
	@echo "--> Running $(1)..."
	@sed -e 's/@@DATASET_ID@@/$(DATASET_ID)/g' \
		-e 's/@@PROJECT_ID@@/$(PROJECT_ID)/g' \
		-e 's/@@LOCATION@@/$(LOCATION)/g' \
		-e 's/@@BQ_CONNECTION_ID@@/$(BQ_CONNECTION_ID)/g' \
		scripts/$(1) | bq query --project_id=$(PROJECT_ID) --nouse_legacy_sql
endef

# --- Individual SQL Script Targets ---
.PHONY: models views
models:
	$(call RUN_SQL,02_models.sql)
views:
	$(call RUN_SQL,02_views.sql)

# --- Cleanup Target ---
.PHONY: clean
clean:
	@echo "--- Tearing down all project resources ---"
	@bq rm -f --dataset --recursive=true "$(PROJECT_ID):$(DATASET_ID)" || echo "Dataset not found."
	@gsutil -m rm -r "gs://$(PROJECT_ID)-sf311-data" || echo "GCS bucket not found."
	@bq rm -f --connection "$(PROJECT_ID).$(LOCATION).$(BQ_CONNECTION_ID)" || echo "Connection not found."
	@echo "--- Teardown complete ---"
