PROJECT_ID ?= sf311-triage-2025
DATASET    ?= sf311
LOCATION   ?= US

.PHONY: all prepare_dirs run_all exports validate quick clean

all: prepare_dirs run_all

prepare_dirs:
	@mkdir -p exports diagrams

SQLS = \
  scripts/02_models.sql \
  scripts/02_views.sql \
  scripts/03_quality_and_cohorts.sql \
  scripts/03_image_summaries.sql \
  scripts/04_case_summaries.sql \
  scripts/04_triage_generate_v2.sql \
  scripts/05_label_taxonomy.sql \
  scripts/05_policy_catalog.sql \
  scripts/05_policy_catalog_upsert.sql \
  scripts/06_embeddings_and_search_tuned.sql \
  scripts/07_refine_prep.sql \
  scripts/07_refinement.sql \
  scripts/08_dashboards.sql \
  scripts/09_proto_comparison.sql

run_all:
	@echo "== Bootstrapping GCP project =="
	bash scripts/00_bootstrap.sh
	@echo "== Running SQL scripts in order =="
	@set -e; \
	for f in $(SQLS); do \
		echo "Running $$f"; \
		bq --project_id=$(PROJECT_ID) --location=$(LOCATION) query --use_legacy_sql=false < $$f; \
	done

exports:
	@mkdir -p exports
	bq query --nouse_legacy_sql --format=csv \
	  "SELECT * FROM \`$(PROJECT_ID).$(DATASET).v_proto_comparison_metrics\`" > exports/proto_metrics.csv
	bq query --nouse_legacy_sql --format=csv \
	  "SELECT * FROM \`$(PROJECT_ID).$(DATASET).v_alignment_pie\`" > exports/alignment_pie.csv
	bq query --nouse_legacy_sql --format=csv \
	  "SELECT * FROM \`$(PROJECT_ID).$(DATASET).v_mismatch_examples\`" > exports/mismatch_examples.csv

validate:
	bq query --nouse_legacy_sql < scripts/10_validation.sql

quick: run_all validate exports

clean:
	rm -f exports/*.csv
