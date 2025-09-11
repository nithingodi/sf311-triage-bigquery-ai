# ==========================================================
# City311 Multimodal Triage with BigQuery AI — Makefile
# ==========================================================

# -------- Defaults (reviewer can override with PROJECT_ID=...) --------
PROJECT_ID ?= $(shell gcloud config get-value project 2>/dev/null)
LOCATION   ?= US
DATASET    ?= sf311

# Your historical project string that may appear in SQL files (we rewrite on the fly)
CANONICAL_PROJECT ?= sf311-triage-2025

# Guardrails
ifeq ($(strip $(PROJECT_ID)),)
$(error PROJECT_ID is empty. Run `gcloud config set project <id>` or pass PROJECT_ID=<id>)
endif

# -------- Helpers --------
# RUN_SQL: streams a SQL file through sed to rewrite any hardcoded project,
# then executes it in BigQuery (US, Standard SQL). Fails fast on error.
define RUN_SQL
  echo "== Running $(1) =="; \
  set -euo pipefail; \
  sed -e 's/`$(CANONICAL_PROJECT)\.$(DATASET)/`$(PROJECT_ID).$(DATASET)/g' \
      -e 's/\b$(CANONICAL_PROJECT)\.$(DATASET)\b/$(PROJECT_ID).$(DATASET)/g' \
      "$(1)" \
  | bq query --nouse_legacy_sql --location=$(LOCATION)
endef

# Ordered list of SQL scripts to run (keeps your original flow)
SQL_ORDER := \
  $(wildcard scripts/02_*.sql) \
  $(wildcard scripts/03_*.sql) \
  $(wildcard scripts/04_*.sql) \
  $(wildcard scripts/05_*.sql) \
  $(wildcard scripts/06_*.sql) \
  $(wildcard scripts/07_*.sql) \
  $(wildcard scripts/08_*.sql) \
  $(wildcard scripts/09_*.sql)

# ==========================================================
# Targets
# ==========================================================
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
	@# Add your export commands here (if any). Example:
	@# bq extract --destination_format=CSV $(PROJECT_ID):$(DATASET).some_table gs://$(PROJECT_ID)-data/exports/some_table.csv
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
	@echo
	@echo "Usage:"
	@echo "  make run_all PROJECT_ID=<your-gcp-project-id>"
