-- 07_refinement.sql
DECLARE project_id STRING DEFAULT '${PROJECT_ID}';
DECLARE dataset    STRING DEFAULT '${DATASET}';

CREATE OR REPLACE TABLE `${PROJECT_ID}.${DATASET}.batch_triage_policy_refined_v2` AS
WITH base AS (
  -- Make sure sr.service_request_id is selected here.
  SELECT
    sr.service_request_id,
    sr.summary,
    sr.summary_source,
    sr.theme,
    sr.severity,
    sr.original_action,
    pm.policy_title,
    pm.policy_snippet,
    pm.source_url
  FROM `${PROJECT_ID}.${DATASET}.triage_results` AS sr
  JOIN `${PROJECT_ID}.${DATASET}.policy_match_best` AS pm
    ON sr.service_request_id = pm.service_request_id
),
refined AS (
  SELECT
    service_request_id,
    summary,
    summary_source,
    theme,
    severity,
    original_action,
    policy_title,
    policy_snippet,
    source_url,
    AI.GENERATE_TEXT(STRUCT(CONCAT(
      'Policy: ', policy_title, '\nSnippet: ', policy_snippet,
      '\nComplaint: ', summary,
      '\nOriginal action: ', original_action,
      '\nRewrite the action to strictly follow the policy. One imperative sentence.'
    ) AS prompt)) AS refined_action
  FROM base
)
SELECT
  service_request_id,
  summary,
  summary_source,
  theme,
  severity,
  original_action,
  policy_title,
  policy_snippet,
  source_url,
  refined_action,
  IF(REGEXP_CONTAINS(LOWER(refined_action), LOWER(SPLIT(policy_title,' ')[SAFE_OFFSET(0)])), 'aligned', 'review') AS alignment;
