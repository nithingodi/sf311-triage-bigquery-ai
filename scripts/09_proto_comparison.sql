




-- Builds a unified prototype pool by joining summaries, triage results, and policy matches.
CREATE OR REPLACE TABLE `sf311-triage-2025.sf311._proto_pool` AS
SELECT
  s.service_request_id,
  s.summary,
  s.summary_source,
  r.triage_result AS tri_obj,
  m.policy_title,
  m.target_theme,
  m.source_url,
  m.cosine_distance,
  m.service_request_id IS NOT NULL AS policy_matched
FROM `sf311-triage-2025.sf311.batch_case_summaries` AS s
LEFT JOIN `sf311-triage-2025.sf311.batch_triage_raw_v2` AS r USING (service_request_id)
LEFT JOIN `sf311-triage-2025.sf311.batch_policy_matches_v2` AS m USING (service_request_id);


-- Parses the JSON fields from the raw triage results into structured columns.
CREATE OR REPLACE TABLE `sf311-triage-2025.sf311._proto_pool_parsed` AS
SELECT
  service_request_id,
  summary,
  summary_source,
  TRIM(JSON_VALUE(tri_obj, '$.theme')) AS theme,
  CASE LOWER(TRIM(JSON_VALUE(tri_obj, '$.severity')))
    WHEN 'low' THEN 'low'
    WHEN 'medium' THEN 'medium'
    WHEN 'high' THEN 'high'
    ELSE 'medium'
  END AS severity,
  TRIM(JSON_VALUE(tri_obj, '$.suggested_action')) AS suggested_action,
  policy_matched,
  policy_title,
  target_theme,
  source_url,
  cosine_distance
FROM `sf311-triage-2025.sf311._proto_pool`;


-- Creates a top-1000 pool of the best-matched cases for analysis.
CREATE OR REPLACE TABLE `sf311-triage-2025.sf311.prototype_1000` AS
SELECT *
FROM `sf311-triage-2025.sf311._proto_pool_parsed`
WHERE summary IS NOT NULL
ORDER BY policy_matched DESC, cosine_distance ASC NULLS LAST, service_request_id
LIMIT 1000;


-- Creates a full cohort analysis table by removing the slice-based limits.
CREATE OR REPLACE TABLE `sf311-triage-2025.sf311._full_cohort_analysis` AS
SELECT *
FROM `sf311-triage-2025.sf311.prototype_1000`
WHERE summary_source IN ('text','image');


-- Creates a final view to calculate and compare the policy match rate
-- for the text-only cohort vs. the combined AI (text + image) cohort.
CREATE OR REPLACE VIEW `sf311-triage-2025.sf311.v_proto_comparison_metrics` AS
WITH text_only AS (
  SELECT
    'No-AI (Text-only)' AS cohort,
    COUNT(*) AS total,
    COUNTIF(policy_matched) AS matched,
    SAFE_DIVIDE(COUNTIF(policy_matched), COUNT(*)) AS match_rate
  FROM `sf311-triage-2025.sf311._full_cohort_analysis`
  WHERE summary_source = 'text'
),
ai_multi AS (
  SELECT
    'With AI (Text+Image)' AS cohort,
    COUNT(*) AS total,
    COUNTIF(policy_matched) AS matched,
    SAFE_DIVIDE(COUNTIF(policy_matched), COUNT(*)) AS match_rate
  FROM `sf311-triage-2025.sf311._full_cohort_analysis`
)
SELECT * FROM text_only
UNION ALL
SELECT * FROM ai_multi;
