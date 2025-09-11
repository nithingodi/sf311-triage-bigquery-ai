-- Project: City311 Multimodal Triage with BigQuery AI
-- Script: 07_refine_prep.sql
-- Purpose:
--   Parse LLM triage JSON and join the tuned policy match to prepare rows
--   for policy-aware action refinement.
-- Outputs:
--   triage_todo_v2 (TABLE)
-- Idempotency: CREATE OR REPLACE (safe). Final table untouched.

-- ===========
-- PARAMETERS
-- ===========
DECLARE project_id STRING DEFAULT "@PROJECT_ID";
DECLARE dataset    STRING DEFAULT "@DATASET";
DECLARE todo_limit INT64  DEFAULT 200;

-- ==========================================================
-- Ensure refined table exists
-- ==========================================================
EXECUTE IMMEDIATE FORMAT("""
CREATE TABLE IF NOT EXISTS `%s.%s.batch_triage_policy_refined_v2` (
  service_request_id STRING,
  summary            STRING,
  summary_source     STRING,
  theme              STRING,
  severity           STRING,
  original_action    STRING,
  policy_title       STRING,
  policy_snippet     STRING,
  source_url         STRING,
  refined_action     STRING,
  alignment          STRING
);
""", project_id, dataset);

-- ==========================================================
-- Build triage_todo_v2
-- ==========================================================
EXECUTE IMMEDIATE FORMAT("""
CREATE OR REPLACE TABLE `%s.%s.triage_todo_v2` AS
WITH parsed AS (
  SELECT
    r.service_request_id,
    s.summary,
    s.summary_source,
    SAFE.PARSE_JSON(r.out_text) AS obj
  FROM `%s.%s.batch_triage_raw_v2` r
  JOIN `%s.%s.batch_case_summaries` s USING (service_request_id)
),
flat AS (
  SELECT
    service_request_id,
    summary,
    summary_source,
    TRIM(JSON_VALUE(obj,'$.theme'))            AS theme,
    LOWER(TRIM(JSON_VALUE(obj,'$.severity')))  AS severity,
    TRIM(JSON_VALUE(obj,'$.suggested_action')) AS original_action
  FROM parsed
),
joined AS (
  SELECT f.*, m.policy_title, m.policy_snippet, m.source_url
  FROM flat f
  LEFT JOIN `%s.%s.batch_policy_matches_v2` m USING (service_request_id)
),
new_only AS (
  SELECT j.*
  FROM joined j
  LEFT JOIN `%s.%s.batch_triage_policy_refined_v2` e USING (service_request_id)
  WHERE e.service_request_id IS NULL
)
SELECT * FROM new_only
LIMIT todo_limit;
""", project_id, dataset,
     project_id, dataset,
     project_id, dataset,
     project_id, dataset,
     project_id, dataset);
