# City311 — Makefile (rendered SQL + idempotent bootstrap)
SHELL := /bin/bash

PROJECT_ID ?= $(shell gcloud config get-value project 2>/dev/null)
LOCATION   ?= US
DATASET    ?= sf311
BUCKET     ?= $(PROJECT_ID)-data
CONN       ?= us_gemini_conn

ifeq ($(strip $(PROJECT_ID)),)
$(error PROJECT_ID is empty. Run: gcloud config set project YOUR_PROJECT_ID)
endif

BQQ = bq --project_id=$(PROJECT_ID) --location=$(LOCATION) query --nouse_legacy_sql --quiet
DRY = bq --project_id=$(PROJECT_ID) --location=$(LOCATION) query --nouse_legacy_sql --quiet --dry_run

# Render ${...} into SQL before BigQuery sees it
RUN_SQL = @echo "== Running scripts/$1"; \
          env PROJECT_ID=$(PROJECT_ID) DATASET=$(DATASET) LOCATION=$(LOCATION) BUCKET=$(BUCKET) CONN=$(CONN) \
          envsubst < scripts/$1 | $(BQQ)

LINT_SQL = @echo "== Dry-run scripts/$1"; \
           env PROJECT_ID=$(PROJECT_ID) DATASET=$(DATASET) LOCATION=$(LOCATION) BUCKET=$(BUCKET) CONN=$(CONN) \
           envsubst < scripts/$1 | $(DRY)

.PHONY: run_all bootstrap sql exports verify refresh lint clean reset

run_all: bootstrap sql

bootstrap:
	@bash scripts/00_bootstrap.sh "$(PROJECT_ID)" "$(LOCATION)" "$(DATASET)" "$(BUCKET)" "$(CONN)"

sql:
	$(call RUN_SQL,02_models.sql)
	$(call RUN_SQL,02_views.sql)
	$(call RUN_SQL,03_quality_and_cohorts.sql)
	$(call RUN_SQL,03_image_summaries.sql)
	$(call RUN_SQL,04_case_summaries.sql)
	$(call RUN_SQL,04_triage_generate_v2.sql)
	$(call RUN_SQL,05_label_taxonomy.sql)
	# Keep only the upsert to avoid conflicts
	$(call RUN_SQL,05_policy_catalog_upsert.sql)
	$(call RUN_SQL,06_embeddings_and_search_tuned.sql)
	$(call RUN_SQL,07_refine_prep.sql)
	$(call RUN_SQL,07_refinement.sql)
	$(call RUN_SQL,08_dashboards.sql)
	$(call RUN_SQL,09_proto_comparison.sql)

lint:
	$(call LINT_SQL,02_models.sql)
	$(call LINT_SQL,02_views.sql)
	$(call LINT_SQL,03_quality_and_cohorts.sql)
	$(call LINT_SQL,03_image_summaries.sql)
	$(call LINT_SQL,04_case_summaries.sql)
	$(call LINT_SQL,04_triage_generate_v2.sql)
	$(call LINT_SQL,05_label_taxonomy.sql)
	$(call LINT_SQL,05_policy_catalog_upsert.sql)
	$(call LINT_SQL,06_embeddings_and_search_tuned.sql)
	$(call LINT_SQL,07_refine_prep.sql)
	$(call LINT_SQL,07_refinement.sql)
	$(call LINT_SQL,08_dashboards.sql)
	$(call LINT_SQL,09_proto_comparison.sql)

exports:
	@mkdir -p exports
	@$(BQQ) 'SELECT * FROM `$(PROJECT_ID).$(DATASET).v_proto_comparison_metrics`' > exports/proto_metrics.csv
	@$(BQQ) 'SELECT * FROM `$(PROJECT_ID).$(DATASET).v_alignment_pie`' > exports/alignment_pie.csv
	@$(BQQ) 'SELECT * FROM `$(PROJECT_ID).$(DATASET).v_mismatch_examples`' > exports/mismatch_examples.csv
	@echo "Exports written to ./exports"

verify:
	@echo "Project: $(PROJECT_ID) | Location: $(LOCATION) | Dataset: $(DATASET) | Bucket: gs://$(BUCKET) | Connection: $(CONN)"

refresh:
	@git fetch origin && git reset --hard origin/main && git clean -xfd

clean:
	-@gcloud storage buckets delete -q gs://$(BUCKET) 2>/dev/null || true
	-@bq --project_id=$(PROJECT_ID) --location=$(LOCATION) rm -r -f -d $(PROJECT_ID):$(DATASET) || true

reset: clean run_all
