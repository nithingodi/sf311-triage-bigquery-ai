-- Project: City311 Multimodal Triage with BigQuery AI
-- Script: 03_quality_and_cohorts.sql
-- Purpose: Score raw complaint text quality and assemble a mixed demo cohort
--          (good-text + image-fallback cases).
-- Inputs:  sf311.cases_norm
-- Outputs: VIEW  sf311.cases_text_quality
--          TABLE sf311.batch_ids_demo
--          TABLE sf311.batch_ids           (pointer to "active" cohort; can be swapped later)
--          TABLE sf311.batch_fallback_ids  (subset needing image summaries)
-- Idempotency: CREATE OR REPLACE for views; tables are replaced to keep runs deterministic.
-- Parameters: project/dataset; sample sizes for demo cohort.
-- Next: 03_image_summaries.sql (summarize fallback images), then 04_triage.sql (text-first triage)

-- 03_quality_and_cohorts.sql
CREATE OR REPLACE VIEW `sf311-triage-2025.sf311.cases_text_quality` AS
WITH src AS (
  SELECT service_request_id, request_type, media_url,
         COALESCE(request_details, request_type) AS text_raw
  FROM `sf311-triage-2025.sf311.cases_norm`
),
norm AS (
  SELECT service_request_id, request_type, media_url,
         TRIM(REGEXP_REPLACE(REPLACE(REPLACE(text_raw, '_',' '), '-',' '), r'\s+', ' ')) AS text_norm
  FROM src
)
SELECT
  service_request_id, request_type, media_url, text_norm,
  (media_url IS NOT NULL AND TRIM(media_url) <> '') AS has_media,
  (
    text_norm IS NULL OR text_norm = '' OR LENGTH(text_norm) < 5 OR
    LOWER(text_norm) IN ('open','other','accepted','unknown','none','na','n/a')
  ) AS is_bad_text
FROM norm;

CREATE OR REPLACE TABLE `sf311-triage-2025.sf311.batch_ids_demo` AS
WITH q AS (
  SELECT service_request_id, is_bad_text, has_media
  FROM `sf311-triage-2025.sf311.cases_text_quality`
),
good AS (
  SELECT service_request_id FROM q WHERE is_bad_text = FALSE ORDER BY RAND() LIMIT 200
),
needs_img AS (
  SELECT service_request_id FROM q WHERE is_bad_text = TRUE AND has_media ORDER BY RAND() LIMIT 800
)
SELECT * FROM good
UNION ALL
SELECT * FROM needs_img;

CREATE OR REPLACE TABLE `sf311-triage-2025.sf311.batch_ids` AS
SELECT * FROM `sf311-triage-2025.sf311.batch_ids_demo`;

CREATE OR REPLACE TABLE `sf311-triage-2025.sf311.batch_fallback_ids` AS
SELECT q.service_request_id
FROM `sf311-triage-2025.sf311.cases_text_quality` q
JOIN `sf311-triage-2025.sf311.batch_ids` b USING (service_request_id)
WHERE q.is_bad_text = TRUE AND q.has_media = TRUE;

