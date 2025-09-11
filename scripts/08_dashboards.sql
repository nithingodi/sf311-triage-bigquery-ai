-- Project: City311 Multimodal Triage with BigQuery AI
-- Script: 08_dashboards.sql
-- Purpose:
--   Produce chart/snippet tables for the writeup:
--     - Alignment pie (match / mismatch-corrected / no_policy)
--     - Mismatch examples (before → after)
-- Outputs:
--   v_alignment_pie (VIEW), v_mismatch_examples (VIEW)
-- Idempotency: CREATE OR REPLACE (safe)

-- ===========
-- PARAMETERS
-- ===========
DECLARE project_id STRING DEFAULT "@PROJECT_ID";
DECLARE dataset    STRING DEFAULT "@DATASET";

-- ==========================================================
-- Alignment distribution (pie chart)
-- ==========================================================
EXECUTE IMMEDIATE FORMAT("""
CREATE OR REPLACE VIEW `%s.%s.v_alignment_pie` AS
SELECT
  alignment,
  COUNT(*) AS ct,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM `%s.%s.batch_triage_policy_refined_v2`
GROUP BY alignment
ORDER BY ct DESC;
""", project_id, dataset, project_id, dataset);

-- ==========================================================
-- Mismatch examples (before → after)
-- ==========================================================
EXECUTE IMMEDIATE FORMAT("""
CREATE OR REPLACE VIEW `%s.%s.v_mismatch_examples` AS
SELECT
  service_request_id,
  theme,
  severity,
  policy_title,
  source_url,
  original_action AS before_action,
  refined_action  AS after_action,
  alignment
FROM `%s.%s.batch_triage_policy_refined_v2`
WHERE alignment = 'mismatch-corrected'
ORDER BY service_request_id
LIMIT 25;
""", project_id, dataset, project_id, dataset);
