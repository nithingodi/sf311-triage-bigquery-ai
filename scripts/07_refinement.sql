-- Inserts refined triage results into the final table
INSERT INTO `@@PROJECT_ID@@.@@DATASET_ID@@.batch_triage_policy_refined_v2` (
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
  alignment
)
WITH refined AS (
  SELECT
    t.*,
    ML.GENERATE_TEXT(
      MODEL `@@PROJECT_ID@@.@@DATASET_ID@@.gemini_text`,  -- Keep your template
      STRUCT(  -- ✅ Change TABLE to STRUCT
        CONCAT(
          'Policy: ', t.policy_title, '\nSnippet: ', t.policy_snippet,
          '\nComplaint: ', t.summary, '\nOriginal action: ', t.original_action,
          '\nRewrite the action to strictly follow the policy. Respond with one imperative sentence only.'
        ) AS prompt
      ),
      STRUCT(0.0 AS temperature)  -- ✅ Change JSON to STRUCT
    ).ml_generate_text_result AS refined_action
  FROM `@@PROJECT_ID@@.@@DATASET_ID@@.triage_todo_v2` AS t
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
  IF(
    REGEXP_CONTAINS(
      LOWER(refined_action),
      LOWER(SPLIT(policy_title, ' ')[SAFE_OFFSET(0)])
    ),
    'aligned', 'review'
  ) AS alignment
FROM refined;
