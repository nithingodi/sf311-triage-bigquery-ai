-- Project: City311 Multimodal Triage with BigQuery AI
-- Script: 07_refinement.sql
-- Purpose:
--   Produce final, policy-aligned actions:
--     (A) Rows WITH a matched policy → LLM refinement with alignment tagging.
--     (B) Rows WITHOUT a policy      → pass-through action, alignment='no_policy'.
-- Inputs:
--   - sf311.triage_todo_v2                (from 07_refine_prep.sql)
--   - us_gemini_conn (CLOUD_RESOURCE)     (Vertex AI access)
-- Outputs:
--   - APPEND rows into sf311.batch_triage_policy_refined_v2
-- Idempotency:
--   - Skips service_request_ids already present in final table.
-- Parameters: project/dataset/connection/endpoint/run_limit

-- ===========
-- PARAMETERS
-- ===========
DECLARE project_id   STRING  DEFAULT 'sf311-triage-2025';
DECLARE dataset      STRING  DEFAULT 'sf311';
DECLARE gem_conn_id  STRING  DEFAULT 'us_gemini_conn';
DECLARE endpoint     STRING  DEFAULT 'gemini-2.0-flash-001';
DECLARE run_limit    INT64   DEFAULT 200;   -- throttle; raise/remove for full runs

-- Ensure final results table exists (noop if present)
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

-- ==============================================
-- (A) WITH POLICY: LLM refinement + alignment
-- ==============================================
EXECUTE IMMEDIATE FORMAT("""
INSERT INTO `%s.%s.batch_triage_policy_refined_v2`
(service_request_id, summary, summary_source, theme, severity, original_action,
 policy_title, policy_snippet, source_url, refined_action, alignment)
WITH todo AS (
  SELECT t.*
  FROM `%s.%s.triage_todo_v2` t
  LEFT JOIN `%s.%s.batch_triage_policy_refined_v2` e USING (service_request_id)
  WHERE t.policy_title IS NOT NULL AND e.service_request_id IS NULL
  ORDER BY t.service_request_id
  LIMIT %d
),
calls AS (
  SELECT
    t.*,
    AI.GENERATE(
      CONCAT(
        'Return ONLY valid JSON: {\"refined_action\":\"\",\"alignment\":\"\"}. ',
        'Set alignment=\"match\" if the original action complies with the policy; ',
        'otherwise set alignment=\"mismatch\" and output ONE compliant imperative sentence in refined_action. ',
        'If original is empty or vague, treat as mismatch and write one compliant action. ',
        'Theme: ', COALESCE(t.theme,'(null)'), '; Severity: ', COALESCE(t.severity,'(null)'), '. ',
        'Complaint summary: ', COALESCE(t.summary,'(null)'), ' ',
        'Policy: ', COALESCE(t.policy_snippet,'(null)'), ' ',
        'Original action: ', COALESCE(t.original_action,'(null)')
      ),
      connection_id => CONCAT('projects/%s/locations/US/connections/%s'),
      endpoint      => '%s',
      model_params  => JSON '{\"generation_config\":{\"temperature\":0,\"response_mime_type\":\"application/json\"}}'
    ).result AS gen_text
  FROM todo t
),
parsed AS (
  SELECT
    service_request_id, summary, summary_source, theme, severity, original_action,
    policy_title, policy_snippet, source_url,
    SAFE.PARSE_JSON(gen_text) AS obj
  FROM calls
)
SELECT
  service_request_id,
  summary,
  summary_source,
  theme,
  CASE LOWER(severity)
    WHEN 'low' THEN 'low' WHEN 'medium' THEN 'medium' WHEN 'high' THEN 'high'
    ELSE 'medium'
  END AS severity,
  original_action,
  policy_title,
  policy_snippet,
  source_url,
  COALESCE(NULLIF(TRIM(JSON_VALUE(obj,'$.refined_action')), ''), original_action) AS refined_action,
  CASE LOWER(TRIM(JSON_VALUE(obj,'$.alignment')))
    WHEN 'mismatch' THEN 'mismatch-corrected'
    WHEN 'match'    THEN 'match'
    ELSE 'match'
  END AS alignment
FROM parsed;
""",
  project_id, dataset,
  project_id, dataset,
  project_id, dataset,
  run_limit,
  project_id, gem_conn_id, endpoint
);

-- ===================================================
-- (B) NO POLICY: pass-through action + alignment tag
-- ===================================================
EXECUTE IMMEDIATE FORMAT("""
INSERT INTO `%s.%s.batch_triage_policy_refined_v2`
(service_request_id, summary, summary_source, theme, severity, original_action,
 policy_title, policy_snippet, source_url, refined_action, alignment)
SELECT
  t.service_request_id,
  t.summary,
  t.summary_source,
  t.theme,
  CASE LOWER(t.severity)
    WHEN 'low' THEN 'low' WHEN 'medium' THEN 'medium' WHEN 'high' THEN 'high'
    ELSE 'medium' END AS severity,
  t.original_action,
  t.policy_title,
  t.policy_snippet,
  t.source_url,
  t.original_action AS refined_action,
  'no_policy'      AS alignment
FROM `%s.%s.triage_todo_v2` t
LEFT JOIN `%s.%s.batch_triage_policy_refined_v2` e USING (service_request_id)
WHERE t.policy_title IS NULL
  AND e.service_request_id IS NULL;
""",
  project_id, dataset,
  project_id, dataset,
  project_id, dataset
);
