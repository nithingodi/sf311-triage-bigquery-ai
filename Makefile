# Makefile

# --- Configuration ---
PROJECT_ID := $(shell gcloud config get-value project)
DATASET_ID := sf311
LOCATION := US
BQ_CONNECTION_ID := sf311-conn

# --- Main Target ---
# This now only runs the SQL scripts, assuming setup is done manually.
.PHONY: run_all
run_all: models views # Add other SQL targets here as needed
	@echo "\n✅ All project scripts completed successfully!"

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
