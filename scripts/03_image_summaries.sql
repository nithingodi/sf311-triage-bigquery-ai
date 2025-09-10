-- Project: City311 Multimodal Triage with BigQuery AI
-- Script: 03_image_summaries.sql
-- Purpose: Summarize fallback complaint images (for cases with poor/empty text).
-- Inputs:  sf311.batch_fallback_ids, sf311.cases_norm
-- Outputs: TABLE sf311.batch_image_summaries (service_request_id, summary_text)
-- Idempotency: Target table is created if missing; inserts are de-duplicated (only new fallback IDs).
-- Parameters: connection id, endpoint, and insert throttle.
-- Notes:
--   - This version uses direct media URLs ONLY when they already have a file extension.
--   - If many media URLs are extension-less or blocked, mirror images to GCS and use OBJ.GET_ACCESS_URL via object tables.

-- ===========
-- PARAMETERS
-- ===========
DECLARE project_id      STRING DEFAULT 'sf311-triage-2025';
DECLARE dataset         STRING DEFAULT 'sf311';
DECLARE gem_conn_id     STRING DEFAULT 'us_gemini_conn';
DECLARE gen_endpoint    STRING DEFAULT 'gemini-2.0-flash-001';
DECLARE insert_limit    INT64  DEFAULT 200;  -- throttle for demo runs; raise/remove for full run

-- ===========================================
-- Results table for image summaries (if absent)
-- ===========================================
EXECUTE IMMEDIATE FORMAT("""
  CREATE TABLE IF NOT EXISTS `%s.%s.batch_image_summaries` (
    service_request_id STRING,
    summary_text STRING
  )
""", project_id, dataset);

-- ===========================================================
-- Insert summaries for fallback rows that have direct image
-- extensions. Skip rows already summarized.
-- ===========================================================
EXECUTE IMMEDIATE FORMAT("""
  INSERT INTO `%s.%s.batch_image_summaries` (service_request_id, summary_text)
  WITH fallback_ext AS (
    SELECT
      CAST(n.service_request_id AS STRING) AS service_request_id,
      n.media_url AS url
    FROM `%s.%s.batch_fallback_ids` b
    JOIN `%s.%s.cases_norm` n USING (service_request_id)
    WHERE n.media_url IS NOT NULL AND TRIM(n.media_url) <> ''
      AND REGEXP_CONTAINS(LOWER(n.media_url), r'\\.(jpg|jpeg|png|gif)(?:$|[?#])')
  ),
  todo AS (
    SELECT f.service_request_id, f.url
    FROM fallback_ext f
    LEFT JOIN `%s.%s.batch_image_summaries` s USING (service_request_id)
    WHERE s.service_request_id IS NULL
    LIMIT %d
  )
  SELECT
    service_request_id,
    AI.GENERATE(
      (
        'Summarize this SF311 complaint photo in one concise sentence (<= 30 words). Return only the sentence.',
        url
      ),
      connection_id => 'projects/%s/locations/US/connections/%s',
      endpoint      => '%s',
      model_params  => JSON '{\"generation_config\":{\"temperature\":0}}'
    ).result AS summary_text
  FROM todo
""",
  project_id, dataset,
  project_id, dataset,
  project_id, dataset,
  project_id, dataset, insert_limit,
  project_id, gem_conn_id, gen_endpoint
);
