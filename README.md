# City311 Multimodal Triage with BigQuery AI

A **SQL-first prototype** that triages San Francisco 311 complaints using **BigQuery AI**:

-   **Generative AI** (`AI.GENERATE`) → structured triage (theme, severity, action)
-   **Vector Search** (`ML.GENERATE_EMBEDDING` + `VECTOR_SEARCH`) → semantic match to official policy catalog
-   **Multimodal AI** (Object Tables) → summarize image-only complaints
-   **Policy Refinement** → refine actions to ensure compliance with regulations
-   **Dashboards** → coverage, match rates, mismatch corrections

---

## 📌 Problem

311 complaints are messy: free-text, often missing details, sometimes just images.
City policy handbooks are dense PDFs. Human triage is slow and inconsistent.

---

## 🚀 Impact

-   **Coverage doubled**: 200 → 400 complaints usable (via AI image summaries)
-   **Policy matches up**: 193 → 393 (+104% lift)
-   **Match rate improved**: 96.5% → 98.3%
-   **Refinement outcomes (317 rows)**:
    -   93% ✅ match
    -   5% ⚠ mismatch-corrected
    -   2% ❌ no policy

---

## 🏗 Architecture
![Architecture](diagrams/architecture.png)

1.  **Object Tables** → summarize complaint images if text is weak/empty
2.  **AI.GENERATE** → triage JSON (theme, severity, action)
3.  **ML.GENERATE_EMBEDDING** + `VECTOR_SEARCH` → match complaint to official policy
4.  **AI.GENERATE** → refine suggested action to align with policy
5.  **Dashboards** → coverage, match rates, mismatch corrections

---

## 📂 Repo Contents

sf311-triage-bigquery-ai/
├── diagrams/architecture.png
├── exports/ # optional CSVs for visuals
├── scripts/
│ 01_policy_ingestion.sql
│ 02_models.sql
│ 02_views.sql
│ 03_quality_and_cohorts.sql
│ 03_image_summaries.sql
│ 04_case_summaries.sql
│ 04_triage_generate_v2.sql
│ 04a_eda_theme_coverage.sql # optional
│ 05_label_taxonomy.sql
│ 05_policy_catalog.sql
│ 05_policy_catalog_upsert.sql
│ 06_embeddings_and_search_tuned.sql
│ 07_refine_prep.sql
│ 07_refinement.sql
│ 08_dashboards.sql
│ 09_proto_comparison.sql
├── survey.txt
└── README.md

---

## 🔧 Repro Steps

> **Run order (via Makefile in Google Cloud Shell):**

1.  Clone the repository and set up the project:
    ```bash
    git clone [https://github.com/nithingodi/sf311-triage-bigquery-ai.git]
    cd sf311-triage-bigquery-ai
    gcloud config set project sf311-471122
    ```

2.  Grant user permissions (one-time setup):
    ```bash
    USER_EMAIL=$(gcloud config get-value account)
    gcloud projects add-iam-policy-binding final-triage-project \
        --member="user:$USER_EMAIL" \
        --role="roles/iam.serviceAccountUser"
    sleep 60
    ```

3.  Create BigQuery dataset and a unified connection:
    ```bash
    # Create dataset
    bq mk --dataset --location=US final-triage-project:sf311

    # Create a unified connection for both Vertex AI (Gemini) and GCS
    bq mk --connection --location=US --project_id=final-triage-project \
        --connection_type=CLOUD_RESOURCE sf311-conn

    # Get service account IDs
    CONNECTION_SA=$(bq show --connection --format=json final-triage-project.US.sf311-conn | jq -r '.cloudResource.serviceAccountId')

    # Grant IAM roles to the unified connection service account
    gcloud projects add-iam-policy-binding final-triage-project \
        --member="serviceAccount:${CONNECTION_SA}" \
        --role="roles/aiplatform.user"
    gcloud projects add-iam-policy-binding final-triage-project \
        --member="serviceAccount:${CONNECTION_SA}" \
        --role="roles/storage.objectViewer"
    sleep 60
    ```

4.  Create object table for images:
    ```bash
    bq query --nouse_legacy_sql "
    CREATE OR REPLACE EXTERNAL TABLE \`final-triage-project.sf311.images_obj_cohort\`
    WITH CONNECTION \`projects/final-triage-project/locations/US/connections/sf311-conn\`
    OPTIONS (
      object_metadata = 'SIMPLE',
      uris = ['gs://final-triage-project-sf311-data/sf311_cohort/images/*']
    );"
    ```

5.  Run the full pipeline (includes data ingestion):
    ```bash
    make run_all
    ```
    - Note: The `make run_all` command now automatically ingests the policy data and sets up the full pipeline.

---

## 📊 Visuals for Writeup

-   **Architecture diagram** → `diagrams/architecture.png`
-   **Bar chart** (No-AI vs With-AI) → query `v_proto_comparison_metrics`
-   **Pie chart** (Alignment split) → query `v_alignment_pie`
-   **Mismatch table** (before → after) → query `v_mismatch_examples`

To export as CSV:
```bash
bq query --nouse_legacy_sql \
  'SELECT * FROM `final-triage-project.sf311.v_proto_comparison_metrics`' > exports/proto_metrics.csv

bq query --nouse_legacy_sql \
  'SELECT * FROM `final-triage-project.sf311.v_alignment_pie`' > exports/alignment_pie.csv

bq query --nouse_legacy_sql \
  'SELECT * FROM `final-triage-project.sf311.v_mismatch_examples`' > exports/mismatch_examples.csv

```

## 📋 Submission Checklist
[x] Writeup (Problem, Impact, Architecture, Results, Limitations, Assets)

[x] Public repo/notebook (this repo)

[x] Diagrams & screenshots included in writeup

[x] Survey.txt (answers: 1mo BigQuery AI, 4mo GCP, feedback)

[x] 

## ⚠️ Limitations
Small policy catalog (hand-curated); real deployment needs full code/policy ingestion.

Demo cohort capped at 400 rows (200 text + 200 image) for free-tier credits.

No full streaming pipeline; batch-only for Kaggle scope.

## 📑 License
MIT


