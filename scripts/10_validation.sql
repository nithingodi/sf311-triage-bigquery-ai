-- Project: City311 Multimodal Triage with BigQuery AI
-- Script: 10_validation.sql
-- Purpose:
--   Build validation views for sanity checks:
--     - Row counts across key tables
--     - JSON parse health
--     - Alignment distribution
-- Outputs:
--   v_validate_counts, v_validate_json, v_validate_alignment (VIEWS)
-- Idempotency: CREATE OR REPLACE (safe)

-- ===========
-- PARAMETERS
-- ===========
DECLARE project_id STRING DEFAULT "@PROJECT_ID";
DECLARE dataset    STRING DEFAULT "@DATASET";

-- ==========================================================
-- Row counts across key artifacts
-- ==========================================================
EXECUTE IMMEDIATE FORMAT("""
CREATE OR REPLACE VIEW `%s.%s.v_validate_counts` AS
WITH t AS (
  SELECT 'cases_norm' AS name, COUNT(*) AS n FROM `%s.%s.cases_norm`
  UNION ALL SELECT 'cases_for_classify', COUNT(*) FROM `%s.%s.cases_for_classify`
  UNION ALL SELECT 'cases_text_quality', COUNT(*) FROM `%s.%s.cases_text_quality`
  UNION ALL SELECT 'batch_ids', COUNT(*) FROM `%s.%s.batch_ids`
  UNION ALL SELECT 'batch_case_summaries', COUNT(*) FROM `%s.%s.batch_case_summaries`
  UNION ALL SELECT 'batch_triage_raw_v2', COUNT(*) FROM `%s.%s.batch_triage_raw_v2`
  UNION ALL SELECT 'policy_chunks', COUNT(*) FROM `%s.%s.policy_chunks`
  UNION ALL SELECT 'policy_embeddings', COUNT(*) FROM `%s.%s.policy_embeddings`
  UNION ALL SELECT 'case_query_embeddings_v2', COUNT(*) FROM `%s.%s.case_query_embeddings_v2`
  UNION ALL SELECT 'batch_policy_matches_v2', COUNT(*) FROM `%s.%s.batch_policy_matches_v2`
  UNION ALL SELECT 'batch_triage_policy_refined_v2', COUNT(*) FROM `%s.%s.batch_triage_policy_refined_v2`
)
SELECT * FROM t ORDER BY name;
""", project_id, dataset,
     project_id, dataset,
     project_id, dataset,
     project_id, dataset,
     project_id, dataset,
     project_id, dataset,
     project_id, dataset,
     project_id, dataset,
     project_id, dataset,
     project_id, dataset,
     project_id, dataset,
     project_id, dataset);

-- ==========================================================
-- JSON health check
-- ==========================================================
EXECUTE IMMEDIATE FORMAT("""
CREATE OR REPLACE VIEW `%s.%s.v_validate_json` AS
SELECT
  COUNTIF(SAFE.PARSE_JSON(out_text) IS NULL) AS bad_json_rows,
  COUNT(*) AS total_rows
FROM `%s.%s.batch_triage_raw_v2`;
""", project_id, dataset,
     project_id, dataset);

-- ==========================================================
-- Alignment distribution
-- ==========================================================
EXECUTE IMMEDIATE FORMAT("""
CREATE OR REPLACE VIEW `%s.%s.v_validate_alignment` AS
SELECT alignment, COUNT(*) ct,
       ROUND(100*COUNT(*)/SUM(COUNT(*)) OVER (),1) pct
FROM `%s.%s.batch_triage_policy_refined_v2`
GROUP BY alignment
ORDER BY ct DESC;
""", project_id, dataset,
     project_id, dataset);
