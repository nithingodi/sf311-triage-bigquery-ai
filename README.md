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
│ 00_bootstrap.sh
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

> **Run order (BigQuery SQL Editor or CLI):**

1.  `bash scripts/00_bootstrap.sh`
2.  `02_models.sql`
3.  `02_views.sql`
4.  `03_quality_and_cohorts.sql`
5.  `03_image_summaries.sql`
6.  `04_case_summaries.sql`
7.  `04_triage_generate_v2.sql`
8.  `05_label_taxonomy.sql`
9.  `05_policy_catalog.sql` and `05_policy_catalog_upsert.sql`
10. `06_embeddings_and_search_tuned.sql`
11. `07_refine_prep.sql`
12. `07_refinement.sql`
13. `08_dashboards.sql`
14. `09_proto_comparison.sql`

---

## 📊 Visuals for Writeup

-   **Architecture diagram** → `diagrams/architecture.png`
-   **Bar chart** (No-AI vs With-AI) → query `v_proto_comparison_metrics`
-   **Pie chart** (Alignment split) → query `v_alignment_pie`
-   **Mismatch table** (before → after) → query `v_mismatch_examples`

To export as CSV:

```bash
bq query --nouse_legacy_sql \
  'SELECT * FROM `sf311-triage-2025.sf311.v_proto_comparison_metrics`' > exports/proto_metrics.csv

bq query --nouse_legacy_sql \
  'SELECT * FROM `sf311-triage-2025.sf311.v_alignment_pie`' > exports/alignment_pie.csv

bq query --nouse_legacy_sql \
  'SELECT * FROM `sf311-triage-2025.sf311.v_mismatch_examples`' > exports/mismatch_examples.csv
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



## To run


# SF311 Triage with BigQuery AI

This project demonstrates how to build an intelligent triage agent for SF311 service requests using BigQuery's built-in AI capabilities.

---
## Setup and Run Instructions

Follow these steps in order in a Google Cloud Shell environment. This process involves a manual step to copy and paste a service account ID from the Google Cloud Console.

### Step 1: Clone Repository and Set Project

First, clone the repository and configure your active Google Cloud project.
```bash
git clone [https://github.com/nithingodi/sf311-triage-bigquery-ai.git](https://github.com/nithingodi/sf311-triage-bigquery-ai.git)
cd sf311-triage-bigquery-ai
gcloud config set project final-triage-project
```

### Step 2: Grant Your User Permissions (One-Time Setup)

This is a one-time setup for your user account in this project. It grants the permissions needed to create and manage BigQuery connections.
```bash
USER_EMAIL=$(gcloud config get-value account)
gcloud projects add-iam-policy-binding final-triage-project \
    --member="user:$USER_EMAIL" \
    --role="roles/iam.serviceAccountUser"
echo "Waiting 60 seconds for permissions to become active..."
sleep 60
```

### Step 3: Create BigQuery Resources

Run the following commands to create the necessary BigQuery dataset and connection.
```bash
# Create the dataset
bq mk --dataset --location=US final-triage-project:sf311

# Create the connection
bq mk --connection --location=US --project_id=final-triage-project --connection_type=CLOUD_RESOURCE sf311-conn
```

### Step 4: Find and Copy the Service Account ID (Manual UI Step)

Now, you will navigate to the Google Cloud Console to find the service account that was just created.

1.  **Open this link in a new tab:** [BigQuery Connections](https://console.cloud.google.com/bigquery/connections)
2.  Make sure you have the correct project (`final-triage-project`) selected at the top of the page.
3.  Click on the connection named **`us.sf311-conn`**.
4.  On the "Connection info" screen, find the **Service account ID** field and click the **Copy** icon next to it. It will look like `bqcx-...@gcp-sa-bigquery-condel.iam.gserviceaccount.com`.



### Step 5: Grant Permissions to the Service Account (Manual Paste Step)

Come back to your Cloud Shell terminal. **Paste the service account ID** you just copied into the command below, replacing `<PASTE_YOUR_SERVICE_ACCOUNT_ID_HERE>`.
```bash
gcloud projects add-iam-policy-binding final-triage-project \
    --member="serviceAccount:<PASTE_YOUR_SERVICE_ACCOUNT_ID_HERE>" \
    --role="roles/aiplatform.user"
```

### Step 6: Run the Project

Now that the manual setup is complete, run the project's data processing and model creation steps using the `make` command.
```bash
make run_all
```


