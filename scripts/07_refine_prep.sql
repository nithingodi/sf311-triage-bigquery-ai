-- Project: City311 Multimodal Triage with BigQuery AI
-- Script: 07_refine_prep.sql
-- Purpose:
--   Parse LLM triage JSON and join the tuned policy match to prepare rows
--   for policy-aware action refinement.
-- Inputs:
--   - sf311.batch_triage_raw_v2
--   - sf311.batch_case_summaries
--   - sf311.batch_policy_matches_v2  (from 06_embeddings_and_search_tuned.sql)
--   - sf311.batch_triage_policy_refined_v2 (to skip already-done rows)
-- Outputs:
--   - TABLE sf311.triage_todo_v2
-- Idempotency: CREATE OR REPLACE (safe). Final table is untouched here.

DECLARE project_id STRING DEFAULT 'sf311-triage-2025';
DECLARE dataset    STRING DEFAULT 'sf311';
DECLARE todo_limit INT64  DEFAULT 200;  -- demo throttle

-- Ensure final table exists (noop if present)
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
  )
""", project_id, dataset);

-- Build todo staging rows
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
    SELECT
      f.*,
      m.policy_title,
      m.policy_snippet,
      m.source_url
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
  LIMIT %d
""",
  project_id, dataset,
  project_id, dataset,
  project_id, dataset,
  project_id, dataset,
  project_id, dataset,
  todo_limit
);
