# Makefile

# Automatically get the currently configured GCP Project ID
PROJECT_ID := $(shell gcloud config get-value project)

# --- Centralized Configuration ---
# All resource names are defined here for consistency.
DATASET_ID := sf311
LOCATION := US
BQ_CONNECTION_ID := sf311-conn

# The main target to run the entire pipeline from start to finish
.PHONY: run_all
run_all: bootstrap models views quality_and_cohorts image_summaries case_summaries triage policy_catalog embeddings refinement dashboards comparison
	@echo "\n✅ All steps completed successfully for project $(PROJECT_ID)!"

# Target to set up all necessary infrastructure
.PHONY: bootstrap
bootstrap:
	@echo "--- 1. Bootstrapping GCP Resources ---"
	@bash scripts/00_bootstrap.sh

# A helper function to run SQL scripts. It replaces all placeholders.
define RUN_SQL
	@echo "--> Running $(1)..."
	@sed -e 's/@@DATASET_ID@@/$(DATASET_ID)/g' \
		-e 's/@@PROJECT_ID@@/$(PROJECT_ID)/g' \
		-e 's/@@LOCATION@@/$(LOCATION)/g' \
		-e 's/@@BQ_CONNECTION_ID@@/$(BQ_CONNECTION_ID)/g' \
		scripts/$(1) | bq query --project_id=$(PROJECT_ID) --nouse_legacy_sql
endef

# --- Targets for each individual SQL script ---
.PHONY: models views quality_and_cohorts image_summaries case_summaries triage policy_catalog embeddings refinement dashboards comparison
models:
	$(call RUN_SQL,02_models.sql)
views:
	$(call RUN_SQL,02_views.sql)
quality_and_cohorts:
	$(call RUN_SQL,03_quality_and_cohorts.sql)
image_summaries:
	$(call RUN_SQL,03_image_summaries.sql)
case_summaries:
	$(call RUN_SQL,04_case_summaries.sql)
triage:
	$(call RUN_SQL,04_triage_generate_v2.sql)
policy_catalog:
	$(call RUN_SQL,05_label_taxonomy.sql)
	$(call RUN_SQL,05_policy_catalog.sql)
	$(call RUN_SQL,05_policy_catalog_upsert.sql)
embeddings:
	$(call RUN_SQL,06_embeddings_and_search_tuned.sql)
refinement:
	$(call RUN_SQL,07_refine_prep.sql)
	$(call RUN_SQL,07_refinement.sql)
dashboards:
	$(call RUN_SQL,08_dashboards.sql)
comparison:
	$(call RUN_SQL,09_proto_comparison.sql)

# Target to destroy all created resources for easy cleanup
.PHONY: clean
clean:
	@echo "--- Tearing down all project resources ---"
	@bq rm -f --dataset --recursive=true "$(PROJECT_ID):$(DATASET_ID)" || echo "Dataset not found."
	@gsutil rm -r "gs://$(PROJECT_ID)-sf311-data" || echo "GCS bucket not found."
	@bq rm -f --connection "$(PROJECT_ID).$(LOCATION).$(BQ_CONNECTION_ID)" || echo "Connection not found."
	@echo "--- Teardown complete ---"
