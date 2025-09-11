-- Project: City311 Multimodal Triage with BigQuery AI
-- Script: 03_quality_and_cohorts.sql
-- Purpose: Score raw complaint text quality and assemble a mixed demo cohort
-- Inputs:  cases_norm view
-- Outputs: cases_text_quality (VIEW), batch_ids_demo (TABLE), batch_ids (TABLE), batch_fallback_ids (TABLE)
-- Idempotency: CREATE OR REPLACE (safe)

-- ===========
-- PARAMETERS
-- ===========
DECLARE project_id STRING DEFAULT "@PROJECT_ID";
DECLARE dataset    STRING DEFAULT "@DATASET";

-- =======================================
-- View: cases_text_quality
-- =======================================
EXECUTE IMMEDIATE FORMAT("""
CREATE OR REPLACE VIEW `%s.%s.cases_text_quality` AS
WITH src AS (
  SELECT service_request_id, request_type, media_url,
         COALESCE(request_details, request_type) AS text_raw
  FROM `%s.%s.cases_norm`
),
norm AS (
  SELECT service_request_id, request_type, media_url,
         TRIM(REGEXP_REPLACE(REPLACE(REPLACE(text_raw, '_',' '), '-',' '), r'\\s+', ' ')) AS text_norm
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
""", project_id, dataset, project_id, dataset);

-- =======================================
-- Table: batch_ids_demo
-- =======================================
EXECUTE IMMEDIATE FORMAT("""
CREATE OR REPLACE TABLE `%s.%s.batch_ids_demo` AS
WITH q AS (
  SELECT service_request_id, is_bad_text, has_media
  FROM `%s.%s.cases_text_quality`
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
""", project_id, dataset, project_id, dataset);

-- =======================================
-- Table: batch_ids
-- =======================================
EXECUTE IMMEDIATE FORMAT("""
CREATE OR REPLACE TABLE `%s.%s.batch_ids` AS
SELECT * FROM `%s.%s.batch_ids_demo`;
""", project_id, dataset, project_id, dataset);

-- =======================================
-- Table: batch_fallback_ids
-- =======================================
EXECUTE IMMEDIATE FORMAT("""
CREATE OR REPLACE TABLE `%s.%s.batch_fallback_ids` AS
SELECT q.service_request_id
FROM `%s.%s.cases_text_quality` q
JOIN `%s.%s.batch_ids` b USING (service_request_id)
WHERE q.is_bad_text = TRUE AND q.has_media = TRUE;
""", project_id, dataset, project_id, dataset, project_id, dataset);
