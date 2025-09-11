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

-- 03_image_summaries.sql
CREATE TABLE IF NOT EXISTS `sf311-triage-2025.sf311.batch_image_summaries`
(service_request_id STRING, summary_text STRING);

INSERT INTO `sf311-triage-2025.sf311.batch_image_summaries` (service_request_id, summary_text)
WITH fallback_ext AS (
  SELECT CAST(n.service_request_id AS STRING) AS service_request_id, n.media_url AS url
  FROM `sf311-triage-2025.sf311.batch_fallback_ids` b
  JOIN `sf311-triage-2025.sf311.cases_norm` n USING (service_request_id)
  WHERE n.media_url IS NOT NULL AND TRIM(n.media_url) <> ''
    AND REGEXP_CONTAINS(LOWER(n.media_url), r'\.(jpg|jpeg|png|gif)(?:$|[?#])')
),
todo AS (
  SELECT f.service_request_id, f.url
  FROM fallback_ext f
  LEFT JOIN `sf311-triage-2025.sf311.batch_image_summaries` s USING (service_request_id)
  WHERE s.service_request_id IS NULL
  LIMIT 200  -- throttle
)
SELECT
  service_request_id,
  AI.GENERATE(
    (
      'Summarize this SF311 complaint photo in one concise sentence (<= 30 words). Return only the sentence.',
      url
    ),
    connection_id => 'projects/sf311-triage-2025/locations/US/connections/us_gemini_conn',
    endpoint      => 'gemini-2.0-flash-001',
    model_params  => JSON '{"generation_config":{"temperature":0}}'
  ).result AS summary_text
FROM todo;

