## City311 Multimodal Triage with BigQuery AI

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
| No-AI (Text-only) | 500 | 240 | **48.0%** |
| With AI (Text+Image) | 1000 | 740 | **74.0%** |

This represents a **+26-point lift** in the policy match rate, a **54% relative improvement** in performance.

### Qualitative Impact: Before vs. After

The agent consistently transforms vague summaries and generic actions into specific, policy-aware recommendations.

| Complaint Summary                                                  | Original Action                                              | Matched Policy Title                | ✅ Refined Action                                                                                           |
|:-------------------------------------------------------------------|:-------------------------------------------------------------|:------------------------------------|:------------------------------------------------------------------------------------------------------------|
| Case Resolved Closed: No Response From Pg & E Graffiti In 1 Month. | Contact PG&E to address the graffiti issue promptly.         | Graffiti Removal (30 days)          | Notify the property owner of their responsibility to abate the graffiti within 30 days.                     |
| Other On Metal Pole.                                               | Inspect the metal pole for damage and schedule repairs.      | Graffiti Removal (30 days)          | Issue a notice to the property owner to abate the graffiti within 30 days.                                  |
| Structure Needs Painting.                                          | Schedule a building inspection to assess the painting needs. | Graffiti Removal (30 days)          | Issue a graffiti removal notice to the property owner, requiring abatement within 30 days.                  |
| Collapsed Sidewalk.                                                | Dispatch a crew to assess and repair the collapsed sidewalk. | Sidewalk Maintenance (PW Code §706) | Notify the property owner of the hazard and their responsibility to repair the collapsed sidewalk.          |
| Collapsed Sidewalk.                                                | Dispatch a crew to assess and repair the collapsed sidewalk. | Sidewalk Maintenance (PW Code §706) | Notify the property owner of the hazard and their responsibility to repair the collapsed sidewalk.          |
| Damaged Side Sewer Vent Cover.                                     | Dispatch a crew to assess and repair the damaged vent cover. | Sidewalk Maintenance (PW Code §706) | Notify the property owner of their responsibility to repair the damaged vent cover.                         |
| Pavement Defect.                                                   | Dispatch a crew to assess and repair the pavement defect.    | Sidewalk Maintenance (PW Code §706) | Notify the property owner of the pavement defect and their responsibility to repair it.                     |
| Sidewalk In Front Of Property Offensive.                           | Dispatch a crew to clean the sidewalk.                       | Sidewalk Maintenance (PW Code §706) | Notify the property owner of the sidewalk maintenance requirement and potential nuisance violation.         |
| Display Merchandise Blocking Sidewalk.                             | Dispatch an inspector to assess the obstruction.             | Sidewalk Maintenance (PW Code §706) | Notify the property owner of the sidewalk obstruction and potential public nuisance.                        |
| Affixed Improperly.                                                | Inspect the affixed item and ensure proper installation.     | Sidewalk Maintenance (PW Code §706) | Notify the property owner to address the improperly affixed item as a potential hazard and public nuisance. |


Additionally, the final refinement step was successful **65%** of the time, producing an action that was heuristically aligned with the retrieved policy.

---

## 🔧 How to Reproduce

The entire pipeline can be reproduced from a Google Cloud Shell environment. The process is designed to be run sequentially from a fresh clone of the repository.

1.  **Clone the Repository & Set Project**: Start by cloning the repository and setting your active Google Cloud project.

    ```bash
    # --- IMPORTANT: UPDATE THIS VARIABLE ---
    export GCLOUD_PROJECT="your-project-id"
    # ---
    gcloud config set project $GCLOUD_PROJECT
    cd ~
    rm -rf sf311-triage-bigquery-ai
    git clone https://github.com/nithingodi/sf311-triage-bigquery-ai.git
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

3.  **Create Core Infrastructure**: The following commands create the necessary BigQuery dataset and the `CLOUD_RESOURCE` connection that allows BigQuery to communicate with Vertex AI and Google Cloud Storage.

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

4.  **Prepare Cloud Storage Bucket**: These commands will create a new GCS bucket and upload the local complaint images to it. The object table created in the next step will point to these files.

    ```bash
    # Create a GCS bucket (bucket names must be globally unique)
    gsutil mb -l US gs://$GCLOUD_PROJECT-sf311-data

    # Upload the cohort images to the new bucket
    gsutil -m cp -r data/sf311_cohort/images/* gs://$GCLOUD_PROJECT-sf311-data/sf311_cohort/images/
    ```

5.  **Create Object Table for Images**: This step creates the special BigQuery table that points to the image files in Google Cloud Storage.

    ```bash
    bq query --nouse_legacy_sql "
    CREATE OR REPLACE EXTERNAL TABLE \`$GCLOUD_PROJECT.sf311.images_obj_cohort\`
    WITH CONNECTION \`projects/$GCLOUD_PROJECT/locations/US/connections/sf311-conn\`
    OPTIONS (
      object_metadata = 'SIMPLE',
      uris = ['gs://$GCLOUD_PROJECT-sf311-data/sf311_cohort/images/*']
    );"
    ```

6.  **Run the Full Pipeline**: Execute the `Makefile` target to run all the SQL scripts in the correct order. This will build everything from the views and models to the final comparison metrics.

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

* **Small Policy Catalog**: The current policy catalog was hand-curated for this prototype. A production deployment would require a more robust ingestion pipeline to automatically parse and index the full set of city codes and policy documents.
* **Batch-Only Architecture**: The pipeline is designed for batch execution as required by the Kaggle competition scope. It does not include a real-time streaming architecture for immediate, on-arrival complaint processing.

---

## 🚀 Future Work

The current architecture serves as a powerful foundation for several exciting enhancements:

* **Generalization to New Business Domains**: This agent's pattern can be adapted for various business purposes that involve multimodal input and require policy-aligned resolutions. Adapting the agent would involve modifying the initial data preparation scripts to handle the new domain's data structure, creating a new, domain-specific policy catalog, and tuning the AI prompts for the specific use case (e.g., customer support, insurance claims).

* **Enhanced Case-Based Reasoning**: The retrieval step could be enhanced to search not only a static policy catalog but also a historical database of similar, successfully resolved complaints. This would allow the agent to learn from past precedent and suggest proven solutions, potentially reducing the need for a full vector search in common scenarios.

* **Real-Time Streaming Pipeline**: The batch architecture could be evolved into a real-time streaming service using **Cloud Functions** and **Pub/Sub**. This would allow complaints to be triaged, classified, and matched to policies within seconds of their submission.
---

## 📑 License

This project is licensed under the MIT License.



