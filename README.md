# City311 Multimodal Triage with BigQuery AI

This repository contains a SQL-first prototype for a multimodal triage agent that processes San Francisco 311 service requests. The entire pipeline is orchestrated within Google BigQuery, leveraging its native AI capabilities to classify unstructured complaints, match them to official city policies using vector search, and generate refined, policy-aligned actions.
---

## 📌 Problem

City 311 systems are inundated with unstructured data. Complaints arrive as free-form text, often with crucial details missing, and sometimes only as an image with no text at all. On the other side, city policies are stored in dense, hard-to-search documents. This mismatch makes manual triage by city agents slow, inconsistent, and difficult to scale.

---

## 🤖 The Solution: A Multimodal RAG Agent in SQL

This project builds an end-to-end **Retrieval-Augmented Generation (RAG)** agent inside BigQuery to solve this problem. The agent intelligently processes each complaint, retrieves the most relevant city policy, and uses that policy to inform its final recommendation.

The pipeline uses four key BigQuery AI features:

1.  **Multimodal Understanding**: For complaints with poor or missing text, Gemini is used via **Object Tables** to generate a concise summary from the user-submitted image.
2.  **Structured Triage**: Gemini (`AI.GENERATE`) analyzes the complaint summary to extract a structured JSON object containing the `theme`, `severity`, and an initial `suggested_action`.
3.  **Policy Retrieval**: Complaint summaries are converted into vector embeddings (`ML.GENERATE_EMBEDDING`) and compared against a pre-indexed catalog of city policies using `VECTOR_SEARCH` to find the most relevant policy snippet.
4.  **Policy-Grounded Refinement**: A final call to Gemini synthesizes the complaint, the initial action, and the retrieved policy to generate a `refined_action` that is specific, actionable, and aligned with official city regulations.

---

## 🏗 Architecture

A visual representation of the end-to-end pipeline.
![Architecture](diagrams/architecture.png)

---

---

## 🏆 Key Results & Impact

The multimodal AI agent demonstrated a significant improvement over a traditional, text-only approach by effectively processing complaints that were previously unusable.

### Quantitative Impact

By summarizing images for cases with poor text, the AI agent dramatically increased the number of complaints that could be successfully matched to a city policy.

| Cohort | Total Cases | Matched to Policy | Match Rate |
| :--- | :---: | :---: | :---: |
| No-AI (Text-only) | 200 | 116 | **58.0%** |
| With AI (Text+Image) | 400 | 316 | **79.0%** |

This represents a **+21-point lift** in the policy match rate, a **36% relative improvement** in performance.

### Qualitative Impact: Before vs. After

The agent consistently transforms vague summaries and generic actions into specific, policy-aware recommendations.

| Complaint Summary | Original Action | Matched Policy Title | ✅ Refined Action |
| :--- | :--- | :--- | :--- |
| Red Tesla Noplate. | Dispatch parking enforcement to investigate and issue a citation. | 72-Hour Rule | **Dispatch parking enforcement to investigate and warn, cite, or tow the vehicle if it has remained in the same spot for over 72 hours.** |
| Parking Meter. | Dispatch parking enforcement to investigate the meter. | Crosswalk Daylighting (AB 413) | **Dispatch parking enforcement to investigate vehicles parked within 20 feet of the crosswalk.** |

Additionally, the final refinement step was successful **74.3%** of the time, producing an action that was heuristically aligned with the retrieved policy.

---

## 🔧 How to Reproduce

The entire pipeline can be reproduced from a Google Cloud Shell environment. The process is designed to be run sequentially from a fresh clone of the repository.

1.  **Clone the Repository & Set Project**: Start by cloning the repository and setting your active Google Cloud project.

    ```bash
    # --- IMPORTANT: UPDATE THIS VARIABLE ---
    export GCLOUD_PROJECT="your-gcp-project-id-here"
    # ---

    gcloud config set project $GCLOUD_PROJECT
    cd ~
    rm -rf sf311-triage-bigquery-ai
    git clone [https://github.com/nithingodi/sf311-triage-bigquery-ai.git](https://github.com/nithingodi/sf311-triage-bigquery-ai.git)
    cd sf311-triage-bigquery-ai
    ```

2.  **Grant User Permissions**: You must grant your user the ability to act as a Service Account User. This is a one-time setup step for your user in this project.

    ```bash
    USER_EMAIL=$(gcloud config get-value account)
    gcloud projects add-iam-policy-binding $GCLOUD_PROJECT \
        --member="user:$USER_EMAIL" \
        --role="roles/iam.serviceAccountUser"
    echo "Waiting 60 seconds for IAM permissions to propagate..."
    sleep 60
    ```

3.  **Create Core Infrastructure**: The following commands create the necessary BigQuery dataset and the CLOUD_RESOURCE connection that allows BigQuery to communicate with Vertex AI and Google Cloud Storage.

    ```bash
    # Create the BigQuery dataset
    bq mk --dataset --location=US $GCLOUD_PROJECT:sf311

    # Create the unified connection
    bq mk --connection --location=US --project_id=$GCLOUD_PROJECT \
        --connection_type=CLOUD_RESOURCE sf311-conn

    # Get the connection's service account
    CONNECTION_SA=$(bq show --connection --format=json $GCLOUD_PROJECT.US.sf311-conn | jq -r '.cloudResource.serviceAccountId')

    # Grant the connection's service account the required roles
    gcloud projects add-iam-policy-binding $GCLOUD_PROJECT \
        --member="serviceAccount:${CONNECTION_SA}" \
        --role="roles/aiplatform.user"
    gcloud projects add-iam-policy-binding $GCLOUD_PROJECT \
        --member="serviceAccount:${CONNECTION_SA}" \
        --role="roles/storage.objectViewer"
    echo "Waiting 60 seconds for IAM permissions to propagate..."
    sleep 60
    ```
4.  **Create Object Table for Images**: This step creates the special BigQuery table that points to the image files in Google Cloud Storage. (Note: The GCS bucket must be created and populated separately).
    ```bash
    bq query --nouse_legacy_sql "
    CREATE OR REPLACE EXTERNAL TABLE \`$GCLOUD_PROJECT.sf311.images_obj_cohort\`
    WITH CONNECTION \`projects/$GCLOUD_PROJECT/locations/US/connections/sf311-conn\`
    OPTIONS (
      object_metadata = 'SIMPLE',
      uris = ['gs://$GCLOUD_PROJECT-sf311-data/sf311_cohort/images/*']
    );"
    ```

5.  **Run the Full Pipeline**: Execute the `Makefile` target to run all the SQL scripts in the correct order. This will build everything from the views and models to the final comparison metrics.

    ```bash
    make run_all
    ```

---
## 📂 Project Structure

The repository is organized with all SQL scripts in a dedicated directory and a `Makefile` at the root for easy execution.

* `sf311-triage-bigquery-ai/`
    * `Makefile`
    * `README.md`
    * `LICENSE`
    * `survey.txt`
    * `.gitignore`
    * `scripts/`
        * `01_policy_ingestion.sql`
        * `02_models.sql`
        * `02_views.sql`
        * `03_image_summaries.sql`
        * `03_quality_and_cohorts.sql`
        * `04_case_summaries.sql`
        * `04_triage_generate_v2.sql`
        * `05_label_taxonomy.sql`
        * `05_policy_catalog.sql`
        * `05_policy_chunks_for_embedding.sql`
        * `05_policy_chunks_validation.sql`
        * `05_policy_embeddings.sql`
        * `06_embeddings_and_search_tuned.sql`
        * `07_refine_prep.sql`
        * `07_refinement.sql`
        * `08_dashboards.sql`
        * `09_proto_comparison.sql`
        * `10_validation.sql`


---

## ⚠️ Limitations

* **Small Policy Catalog**: The current policy catalog was hand-curated for this prototype. A production deployment would require a more robust ingestion pipeline for the full set of city codes.
* **Batch Processing Only**: The pipeline is designed for batch execution as required by the Kaggle competition scope and does not include a real-time streaming architecture.

---

## 📑 License

This project is licensed under the MIT License.



