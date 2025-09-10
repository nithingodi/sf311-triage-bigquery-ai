-- Project: City311 Multimodal Triage with BigQuery AI
-- Script: 04_case_summaries.sql
-- Purpose: Build a per-case summary for the active cohort:
--          - If text quality is good, use cleaned complaint text
--          - Else, use image summary if available
-- Inputs:  sf311.batch_ids, sf311.cases_for_classify, sf311.cases_text_quality, sf311.batch_image_summaries
-- Outputs: VIEW sf311.batch_case_summaries (service_request_id, summary, summary_source)
-- Idempotency: CREATE OR REPLACE VIEW (safe to re-run)
-- Next: 04_triage_generate.sql (LLM JSON triage)

-- ===========
-- PARAMETERS
-- ===========
DECLARE project_id STRING DEFAULT 'sf311-triage-2025';
DECLARE dataset    STRING DEFAULT 'sf311';

EXECUTE IMMEDIATE FORMAT("""
  CREATE OR REPLACE VIEW `%s.%s.batch_case_summaries` AS
  WITH ids AS (
    SELECT service_request_id
    FROM `%s.%s.batch_ids`
  ),
  text_src AS (
    SELECT
      c.service_request_id,
      cf.complaint_text,
      q.is_bad_text
    FROM ids c
    JOIN `%s.%s.cases_for_classify`   AS cf USING (service_request_id)
    JOIN `%s.%s.cases_text_quality`   AS q  USING (service_request_id)
  ),
  img_src AS (
    SELECT service_request_id, summary_text AS image_summary
    FROM `%s.%s.batch_image_summaries`
  )
  SELECT
    i.service_request_id,
    CASE
      WHEN t.is_bad_text = FALSE THEN t.complaint_text
      WHEN i2.image_summary IS NOT NULL THEN i2.image_summary
      ELSE NULL
    END AS summary,
    CASE
      WHEN t.is_bad_text = FALSE THEN 'text'
      WHEN i2.image_summary IS NOT NULL THEN 'image'
      ELSE 'none'
    END AS summary_source
  FROM ids i
  JOIN text_src t USING (service_request_id)
  LEFT JOIN img_src i2 USING (service_request_id)
""", project_id, dataset,
     project_id, dataset,
     project_id, dataset,
     project_id, dataset,
     project_id, dataset);
