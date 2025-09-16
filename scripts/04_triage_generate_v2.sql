-- Generates raw triage results (theme, severity, action) for each case summary.
CREATE OR REPLACE TABLE `@@PROJECT_ID@@.@@DATASET_ID@@.batch_triage_raw_v2` AS
SELECT
  s.service_request_id,
  s.summary,
  AI.GENERATE(
    (
      SELECT AS STRUCT
        CONCAT(
          'EXTRACT a theme, severity, and action from this SF311 complaint. SEVERITY must be one of: [Low, Medium, High, Critical]. ACTION must be one of: [Dispatch, Maintenance, Information, Policy].',
          ' COMPLAINT: ', s.summary
        ) AS prompt
    ),
    connection_id => 'projects/@@PROJECT_ID@@/locations/@@LOCATION@@/connections/sf311-conn',
    endpoint => 'gemini-2.0-flash-001',
    model_params => JSON '{"generation_config":{"temperature": 0.0, "max_output_tokens": 100}}'
  ).result AS triage_result
FROM `@@PROJECT_ID@@.@@DATASET_ID@@.batch_case_summaries` AS s
WHERE s.summary IS NOT NULL;
