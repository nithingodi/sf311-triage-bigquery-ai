-- Generates raw triage results (theme, severity, action) for each case summary.
CREATE OR REPLACE TABLE `@@PROJECT_ID@@.@@DATASET_ID@@.batch_triage_raw_v2` AS
SELECT
  s.service_request_id,
  s.summary,
  ML.GENERATE_TEXT(
    MODEL `@@PROJECT_ID@@.@@DATASET_ID@@.gemini_text`,
    (SELECT AS STRUCT
      CONCAT(
        'EXTRACT a theme, severity, and action from this SF311 complaint. SEVERITY must be one of: [Low, Medium, High, Critical]. ACTION must be one of: [Dispatch, Maintenance, Information, Policy].',
        ' COMPLAINT: ', s.summary
      ) AS prompt
    ),
    JSON '{"temperature": 0.0, "max_output_tokens": 100}'
  ) AS triage_result
FROM `@@PROJECT_ID@@.@@DATASET_ID@@.batch_case_summaries` AS s
WHERE s.summary IS NOT NULL;
