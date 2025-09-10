City311 Multimodal Triage with BigQuery AI
A SQL-first prototype that triages San Francisco 311 complaints using BigQuery AI:

Generative AI (AI.GENERATE) → structured triage (theme, severity, action)

Vector Search (ML.GENERATE_EMBEDDING + VECTOR_SEARCH) → semantic match to official policy catalog

Multimodal AI (Object Tables) → summarize image-only complaints

Policy Refinement → refine actions to ensure compliance with regulations

Dashboards → coverage, match rates, mismatch corrections

⚡ Quick Start
For a fast setup, use the provided make quick command.

Bash

git clone https://github.com/nithingodi/sf311-triage-bigquery-ai.git
cd sf311-triage-bigquery-ai
make quick
📌 Problem
311 complaints are messy: free-text, often missing details, sometimes just images. 🤦‍♂️ City policy handbooks are dense PDFs. Human triage is slow and inconsistent.

🚀 Impact
Coverage doubled: 200 → 400 complaints usable (via AI image summaries) 📈

Policy matches up: 193 → 393 (+104% lift)

Match rate improved: 96.5% → 98.3%

Refinement outcomes (317 rows):

93% ✅ match

5% ⚠ mismatch-corrected

2% ❌ no policy

🏗 Architecture
Object Tables → summarize complaint images if text is weak/empty

AI.GENERATE → triage JSON (theme, severity, action)

ML.GENERATE_EMBEDDING + VECTOR_SEARCH → match complaint to official policy

AI.GENERATE → refine suggested action to align with policy

Dashboards → coverage, match rates, mismatch corrections

📂 Repo Contents
sf311-triage-bigquery-ai/
├── diagrams/
│   └── architecture.png
├── exports/                 # optional CSVs for visuals
├── scripts/
│   ├── 00_bootstrap.sh
│   ├── 02_models.sql
│   ├── 02_views.sql
│   ├── 03_quality_and_cohorts.sql
│   ├── 03_image_summaries.sql
│   ├── 04_case_summaries.sql
│   ├── 04_triage_generate_v2.sql
│   ├── 04a_eda_theme_coverage.sql   # optional
│   ├── 05_label_taxonomy.sql
│   ├── 05_policy_catalog.sql
│   ├── 05_policy_catalog_upsert.sql
│   ├── 06_embeddings_and_search_tuned.sql
│   ├── 07_refine_prep.sql
│   ├── 07_refinement.sql
│   ├── 08_dashboards.sql
│   └── 09_proto_comparison.sql
├── survey.txt
└── README.md
🔧 Repro Steps
Run order (BigQuery SQL Editor or CLI):

bash scripts/00_bootstrap.sh

02_models.sql

02_views.sql

03_quality_and_cohorts.sql

03_image_summaries.sql

04_case_summaries.sql

04_triage_generate_v2.sql

05_label_taxonomy.sql

05_policy_catalog.sql and 05_policy_catalog_upsert.sql

06_embeddings_and_search_tuned.sql

07_refine_prep.sql

07_refinement.sql

08_dashboards.sql

09_proto_comparison.sql

📊 Visuals for Writeup
Architecture diagram → diagrams/architecture.png

Bar chart (No-AI vs With-AI) → query v_proto_comparison_metrics

Pie chart (Alignment split) → query v_alignment_pie

Mismatch table (before → after) → query v_mismatch_examples

To export as CSV:

Bash

bq query --nouse_legacy_sql \
  'SELECT * FROM `sf311-triage-2025.sf311.v_proto_comparison_metrics`' > exports/proto_metrics.csv

bq query --nouse_legacy_sql \
  'SELECT * FROM `sf311-triage-2025.sf311.v_alignment_pie`' > exports/alignment_pie.csv

bq query --nouse_legacy_sql \
  'SELECT * FROM `sf311-triage-2025.sf311.v_mismatch_examples`' > exports/mismatch_examples.csv
📋 Submission Checklist
[x] Writeup (Problem, Impact, Architecture, Results, Limitations, Assets)

[x] Public repo/notebook (this repo)

[x] Diagrams & screenshots included in writeup

[x] Survey.txt (answers: 1mo BigQuery AI, 4mo GCP, feedback)

[ ] (Optional) Loom/YouTube demo

⚠️ Limitations
Small policy catalog (hand-curated); real deployment needs full code/policy ingestion.

Demo cohort capped at 400 rows (200 text + 200 image) for free-tier credits.

No full streaming pipeline; batch-only for Kaggle scope.

📑 License
MIT
