SHELL := /bin/bash

PROJECT_ID ?= $(shell gcloud config get-value project 2>/dev/null)
LOCATION   ?= US
DATASET    ?= sf311
BUCKET     ?= $(PROJECT_ID)-data
CONN       ?= us_gemini_conn

BQQ = bq --project_id=$(PROJECT_ID) --location=$(LOCATION) query --nouse_legacy_sql --quiet
DRY = bq --project_id=$(PROJECT_ID) --location=$(LOCATION) query --nouse_legacy_sql --quiet --dry_run
PREPROCESS = scripts/preprocess.sh

RUN_SQL = @echo "== Running scripts/$1"; \
  PROJECT_ID=$(PROJECT_ID) DATASET=$(DATASET) LOCATION=$(LOCATION) CONN=$(CONN) \
  $(PREPROCESS) scripts/$1 | envsubst | $(BQQ)

LINT_SQL = @echo "== Lint (dry-run) scripts/$1"; \
  PROJECT_ID=$(PROJECT_ID) DATASET=$(DATASET) LOCATION=$(LOCATION) CONN=$(CONN) \
  $(PREPROCESS) scripts/$1 | envsubst | $(DRY)

.PHONY: run_all bootstrap sql lint verify refresh exports clean reset

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
	$(call RUN_SQL,05_policy_catalog_upsert.sql)
	$(call RUN_SQL,06_embeddings_and_search_tuned.sql)
	$(call RUN_SQL,07_refine_prep.sql)
	$(call RUN_SQL,07_refinement.sql)
	$(call RUN_SQL,08_dashboards.sql)
	$(call RUN_SQL,09_proto_comparison.sql)
	$(call RUN_SQL,10_validation.sql)

verify:
	@echo "== Current environment =="
	@echo "PROJECT_ID: $(PROJECT_ID)"
	@echo "LOCATION: $(LOCATION)"
	@echo "DATASET: $(DATASET)"
	@echo "BUCKET: gs://$(BUCKET)"
	@echo "CONN: $(CONN)"
