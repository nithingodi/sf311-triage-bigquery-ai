-- Ensures the final results table exists with the correct schema.
CREATE TABLE IF NOT EXISTS `@@PROJECT_ID@@.@@DATASET_ID@@.batch_triage_policy_refined_v2` (
  service_request_id STRING,
  summary STRING,
  summary_source STRING,
  theme STRING,
  severity STRING,
  original_action STRING,
  policy_title STRING,
  policy_snippet STRING,
  source_url STRING,
  refined_action STRING,
  alignment STRING
);

-- Prepares the data for the final refinement step.
-- It joins triage results with policy matches and filters for unprocessed cases.
CREATE OR REPLACE TABLE `@@PROJECT_ID@@.@@DATASET_ID@@.triage_todo_v2` AS
WITH parsed AS (
  SELECT
    r.service_request_id,
    s.summary,
    s.summary_source,
    r.triage_result AS obj -- Corrected column name from out_text to triage_result
  FROM `@@PROJECT_ID@@.@@DATASET_ID@@.batch_triage_raw_v2` AS r
  JOIN `@@PROJECT_ID@@.@@DATASET_ID@@.batch_case_summaries` AS s USING (service_request_id)
),
flat AS (
  SELECT
    service_request_id,
    summary,
    summary_source,
    TRIM(JSON_VALUE(obj,'$.theme')) AS theme,
    LOWER(TRIM(JSON_VALUE(obj,'$.severity'))) AS severity,
    TRIM(JSON_VALUE(obj,'$.suggested_action')) AS original_action
  FROM parsed
),
joined AS (
  SELECT f.*, m.policy_title, m.policy_snippet, m.source_url
  FROM flat AS f
  LEFT JOIN `@@PROJECT_ID@@.@@DATASET_ID@@.batch_policy_matches_v2` AS m USING (service_request_id)
),
new_only AS (
  SELECT j.*
  FROM joined AS j
  LEFT JOIN `@@PROJECT_ID@@.@@DATASET_ID@@.batch_triage_policy_refined_v2` AS e USING (service_request_id)
  WHERE e.service_request_id IS NULL
)
SELECT * FROM new_only
LIMIT 200;
