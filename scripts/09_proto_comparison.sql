-- Project: City311 Multimodal Triage with BigQuery AI
-- Script: 09_proto_comparison.sql
-- Purpose:
--   Build a unified prototype pool, parse triage JSON, and produce
--   a balanced 400-case slice (200 text + 200 image) to compare:
--     - No-AI baseline (text-only)
--     - With-AI (text + image summaries)
--   Outputs chart-ready metrics for the bar chart.
-- Inputs:
--   - sf311.batch_case_summaries
--   - sf311.batch_triage_raw_v2
--   - sf311.batch_policy_matches_v2
-- Outputs:
--   - TABLE sf311._proto_pool
--   - TABLE sf311._proto_pool_parsed
--   - TABLE sf311.prototype_1000
--   - TABLE sf311._summarized_400
--   - VIEW  sf311.v_proto_comparison_metrics
-- Idempotency: CREATE OR REPLACE (safe)
-- Notes:
--   - The 400-case slice is constructed as 200 text + 200 image for a balanced demo.
--   - Within each source, we prioritize rows with a policy match, then closest distance.

DECLARE project_id   STRING  DEFAULT 'sf311-triage-2025';
DECLARE dataset      STRING  DEFAULT 'sf311';
DECLARE proto_limit  INT64   DEFAULT 1000;
DECLARE per_source_n INT64   DEFAULT 200;   -- 200 text + 200 image

-- 09_proto_comparison.sql
CREATE OR REPLACE TABLE `sf311-triage-2025.sf311._proto_pool` AS
SELECT
  s.service_request_id,
  s.summary,
  s.summary_source,
  SAFE.PARSE_JSON(r.out_text) AS tri_obj,
  m.policy_title,
  m.target_theme,
  m.source_url,
  m.cosine_distance,
  m.service_request_id IS NOT NULL AS policy_matched
FROM `sf311-triage-2025.sf311.batch_case_summaries` s
LEFT JOIN `sf311-triage-2025.sf311.batch_triage_raw_v2` r USING (service_request_id)
LEFT JOIN `sf311-triage-2025.sf311.batch_policy_matches_v2` m USING (service_request_id);

CREATE OR REPLACE TABLE `sf311-triage-2025.sf311._proto_pool_parsed` AS
SELECT
  service_request_id,
  summary,
  summary_source,
  TRIM(JSON_VALUE(tri_obj, '$.theme')) AS theme,
  CASE LOWER(TRIM(JSON_VALUE(tri_obj, '$.severity')))
    WHEN 'low' THEN 'low' WHEN 'medium' THEN 'medium' WHEN 'high' THEN 'high'
    ELSE 'medium' END AS severity,
  TRIM(JSON_VALUE(tri_obj, '$.suggested_action')) AS suggested_action,
  policy_matched,
  policy_title,
  target_theme,
  source_url,
  cosine_distance
FROM `sf311-triage-2025.sf311._proto_pool`;

CREATE OR REPLACE TABLE `sf311-triage-2025.sf311.prototype_1000` AS
SELECT *
FROM `sf311-triage-2025.sf311._proto_pool_parsed`
WHERE summary IS NOT NULL
ORDER BY policy_matched DESC, cosine_distance ASC NULLS LAST, service_request_id
LIMIT 1000;

-- balanced 200 text + 200 image slice for comparison
CREATE OR REPLACE TABLE `sf311-triage-2025.sf311._summarized_400` AS
WITH ranked AS (
  SELECT
    p.*,
    ROW_NUMBER() OVER (PARTITION BY summary_source
      ORDER BY policy_matched DESC, cosine_distance ASC NULLS LAST, service_request_id) AS rn
  FROM `sf311-triage-2025.sf311.prototype_1000` p
  WHERE summary_source IN ('text','image')
)
SELECT *
FROM ranked
WHERE (summary_source = 'text'  AND rn <= 200)
   OR (summary_source = 'image' AND rn <= 200);

CREATE OR REPLACE VIEW `sf311-triage-2025.sf311.v_proto_comparison_metrics` AS
WITH text_only AS (
  SELECT 'No-AI (Text-only)' AS cohort,
         COUNT(*) AS total,
         COUNTIF(policy_matched) AS matched,
         SAFE_DIVIDE(COUNTIF(policy_matched), COUNT(*)) AS match_rate
  FROM `sf311-triage-2025.sf311._summarized_400`
  WHERE summary_source = 'text'
),
ai_multi AS (
  SELECT 'With AI (Text+Image)' AS cohort,
         COUNT(*) AS total,
         COUNTIF(policy_matched) AS matched,
         SAFE_DIVIDE(COUNTIF(policy_matched), COUNT(*)) AS match_rate
  FROM `sf311-triage-2025.sf311._summarized_400`
)
SELECT * FROM text_only
UNION ALL
SELECT * FROM ai_multi;

