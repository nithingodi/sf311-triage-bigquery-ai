# ==========================================================
# City311 Multimodal Triage with BigQuery AI — Makefile
# ==========================================================

PROJECT_ID ?= $(shell gcloud config get-value project 2>/dev/null)
LOCATION   ?= US
DATASET    ?= sf311
CANONICAL_PROJECT ?= sf311-triage-2025

ifeq ($(strip $(PROJECT_ID)),)
$(error PROJECT_ID is empty. Run `gcloud config set project <id>` or pass PROJECT_ID=<id>)
endif

PROJECT_NUMBER ?= $(shell gcloud projects describe $(PROJECT_ID) --format='value(projectNumber)' 2>/dev/null)

# Stream SQL through rewrites, then run in BigQuery (US, Standard SQL)
define RUN_SQL
  echo "== Running $(1) =="; \
  set -euo pipefail; \
  sed -e 's/`$(CANONICAL_PROJECT)\.$(DATASET)/`$(PROJECT_ID).$(DATASET)/g' \
      -e 's/\b$(CANONICAL_PROJECT)\.$(DATASET)\b/$(PROJECT_ID).$(DATASET)/g' \
      -e 's/@PROJECT_ID/$(PROJECT_ID)/g' \
      -e 's/<YOUR_GCP_PROJECT_ID>/$(PROJECT_ID)/g' \
      -e 's/@PROJECT_NUMBER/$(PROJECT_NUMBER)/g' \
      "$(1)" \
  | bq query --nouse_legacy_sql --location=$(LOCATION)
endef

SQL_ORDER := \
  $(wildcard scripts/02_*.sql) \
  $(wildcard scripts/03_*.sql) \
  $(wildcard scripts/04_*.sql) \
  $(wildcard scripts/05_*.sql) \
  $(wildcard scripts/06_*.sql) \
  $(wildcard scripts/07_*.sql) \
  $(wildcard scripts/08_*.sql) \
  $(wildcard scripts/09_*.sql)

.PHONY: run_all
run_all:
	@echo "== Setup: project =="; gcloud config set project "$(PROJECT_ID)"
	@echo "== Bootstrap (dataset, bucket, connections, IAM) =="
	@PROJECT_ID="$(PROJECT_ID)" LOCATION="$(LOCATION)" DATASET="$(DATASET)" bash scripts/00_bootstrap.sh
	@echo "== Execute SQL stack =="
	@$(foreach f,$(SQL_ORDER),$(call RUN_SQL,$(f));)
	@echo "== All SQL completed ✅ =="

.PHONY: exports
exports:
	@echo "== (Optional) export chart-ready CSVs =="
	@echo "(no exports defined)"

.PHONY: verify
verify:
	@echo "== Verify core artifacts =="
	@echo "-- Models --"; bq ls --location=$(LOCATION) --models $(PROJECT_ID):$(DATASET) || true
	@echo "-- Tables --"; bq ls $(PROJECT_ID):$(DATASET) || true

.PHONY: show-sql
show-sql:
	@printf "%s\n" $(SQL_ORDER)

.PHONY: help
help:
	@echo "Targets:"
	@echo "  run_all   - Bootstrap + run all SQL in order (reviewer default)."
	@echo "  exports   - Optional CSV exports (edit as needed)."
	@echo "  verify    - Quick check of models/tables."
	@echo "  show-sql  - Print the resolved SQL run order."
	@echo ; echo "Usage: make run_all PROJECT_ID=<your-gcp-project-id>"
