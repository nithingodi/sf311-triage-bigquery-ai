-- Builds a unified prototype pool by joining summaries, triage results, and policy matches.
CREATE OR REPLACE TABLE `@@PROJECT_ID@@.@@DATASET_ID@@._proto_pool` AS
SELECT
  s.service_request_id,
  s.summary,
  s.summary_source,
  r.triage_result AS tri_obj, -- Corrected column name
  m.policy_title,
  m.target_theme,
  m.source_url,
  m.cosine_distance,
  m.service_request_id IS NOT NULL AS policy_matched
FROM `@@PROJECT_ID@@.@@DATASET_ID@@.batch_case_summaries` AS s
LEFT JOIN `@@PROJECT_ID@@.@@DATASET_ID@@.batch_triage_raw_v2` AS r USING (service_request_id)
LEFT JOIN `@@PROJECT_ID@@.@@DATASET_ID@@.batch_policy_matches_v2` AS m USING (service_request_id);


-- Parses the JSON fields from the raw triage results into structured columns.
CREATE OR REPLACE TABLE `@@PROJECT_ID@@.@@DATASET_ID@@._proto_pool_parsed` AS
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
FROM `@@PROJECT_ID@@.@@DATASET_ID@@._proto_pool`;


-- Creates a top-1000 pool of the best-matched cases for analysis.
CREATE OR REPLACE TABLE `@@PROJECT_ID@@.@@DATASET_ID@@.prototype_1000` AS
SELECT *
FROM `@@PROJECT_ID@@.@@DATASET_ID@@._proto_pool_parsed`
WHERE summary IS NOT NULL
ORDER BY policy_matched DESC, cosine_distance ASC NULLS LAST, service_request_id
LIMIT 1000;


-- Creates a balanced 400-case slice (200 text-based, 200 image-based) for comparison.
CREATE OR REPLACE TABLE `@@PROJECT_ID@@.@@DATASET_ID@@._summarized_400` AS
WITH ranked AS (
  SELECT
    p.*,
    ROW_NUMBER() OVER (
      PARTITION BY summary_source
      ORDER BY policy_matched DESC, cosine_distance ASC NULLS LAST, service_request_id
    ) AS rn
  FROM `@@PROJECT_ID@@.@@DATASET_ID@@.prototype_1000` AS p
  WHERE summary_source IN ('text','image')
)
SELECT * EXCEPT(rn)
FROM ranked
WHERE (summary_source = 'text'  AND rn <= 200)
   OR (summary_source = 'image' AND rn <= 200);


-- Creates a final view to calculate and compare the policy match rate
-- for the text-only cohort vs. the combined AI (text + image) cohort.
CREATE OR REPLACE VIEW `@@PROJECT_ID@@.@@DATASET_ID@@.v_proto_comparison_metrics` AS
WITH text_only AS (
  SELECT
    'No-AI (Text-only)' AS cohort,
    COUNT(*) AS total,
    COUNTIF(policy_matched) AS matched,
    SAFE_DIVIDE(COUNTIF(policy_matched), COUNT(*)) AS match_rate
  FROM `@@PROJECT_ID@@.@@DATASET_ID@@._summarized_400`
  WHERE summary_source = 'text'
),
ai_multi AS (
  SELECT
    'With AI (Text+Image)' AS cohort,
    COUNT(*) AS total,
    COUNTIF(policy_matched) AS matched,
    SAFE_DIVIDE(COUNTIF(policy_matched), COUNT(*)) AS match_rate
  FROM `@@PROJECT_ID@@.@@DATASET_ID@@._summarized_400`
)
SELECT * FROM text_only
UNION ALL
SELECT * FROM ai_multi;
