# Makefile

# --- Configuration ---
PROJECT_ID := $(shell gcloud config get-value project)
DATASET_ID := sf311
LOCATION := US
BQ_CONNECTION_ID := sf311-conn

# --- Main Target ---
.PHONY: run_all
run_all: models views quality_and_cohorts policy_ingestion image_summaries case_summaries triage label_taxonomy policy_catalog embeddings refinement dashboards comparison
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
models:
	$(call RUN_SQL,02_models.sql)
views:
	$(call RUN_SQL,02_views.sql)
quality_and_cohorts:
	$(call RUN_SQL,03_quality_and_cohorts.sql)
policy_ingestion:
	$(call RUN_SQL,01_policy_ingestion.sql)
image_summaries:
	# --- TO SWITCH PIPELINES: EDIT THE FILENAME ON THE LINE BELOW ---
	# Option 1 (default): 03_image_summaries.sql
	# Option 2 (improved): 03_image_summaries_v2_objtable.sql
	$(call RUN_SQL,03_image_summaries_v2_objtable.sql)
case_summaries:
	$(call RUN_SQL,04_case_summaries.sql)
triage:
	$(call RUN_SQL,04_triage_generate_v2.sql)
label_taxonomy:
	$(call RUN_SQL,05_label_taxonomy.sql)
policy_catalog:
	$(call RUN_SQL,05_policy_chunks_for_embedding.sql)
	$(call RUN_SQL,05_policy_embeddings.sql)
	$(call RUN_SQL,05_policy_catalog.sql)
	$(call RUN_SQL,05_policy_chunks_validation.sql)
embeddings:
	$(call RUN_SQL,06_embeddings_and_search_tuned.sql)
refinement:
	$(call RUN_SQL,07_refine_prep.sql)
	$(call RUN_SQL,07_refinement.sql)
dashboards:
	$(call RUN_SQL,08_dashboards.sql)
comparison:
	$(call RUN_SQL,09_proto_comparison.sql)


# --- Cleanup Targets ---
.PHONY: clean_summaries
clean_summaries:
	@echo "--- Clearing previous image and case summaries ---"
	@bq rm -f -t "$(PROJECT_ID):$(DATASET_ID).batch_image_summaries"
	@bq rm -f -t "$(PROJECT_ID):$(DATASET_ID).batch_case_summaries"

.PHONY: clean
clean:
	@echo "--- Tearing down all project resources ---"
	@bq rm -f --dataset --recursive=true "$(PROJECT_ID):$(DATASET_ID)" || echo "Dataset not found."
	@gsutil -m rm -r "gs://$(PROJECT_ID)-sf311-data" || echo "GCS bucket not found."
	@bq rm -f --connection "$(PROJECT_ID).$(LOCATION).$(BQ_CONNECTION_ID)" || echo "Connection not found."
	@echo "--- Teardown complete ---"
