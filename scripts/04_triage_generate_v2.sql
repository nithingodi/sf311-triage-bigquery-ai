CREATE OR REPLACE TABLE `@@PROJECT_ID@@.@@DATASET_ID@@.batch_triage_raw_v2` AS
WITH s AS (
  SELECT service_request_id, summary, summary_source
  FROM `@@PROJECT_ID@@.@@DATASET_ID@@.batch_case_summaries`
  WHERE summary IS NOT NULL
),
todo AS (
  SELECT s.*
  FROM s
  LEFT JOIN `@@PROJECT_ID@@.@@DATASET_ID@@.batch_triage_raw_v2` r USING (service_request_id)
  WHERE r.service_request_id IS NULL
  LIMIT 500
),
prompts AS (
  SELECT
    t.service_request_id, t.summary, t.summary_source,
    CONCAT(
      'You are a city 311 triage bot. Respond with ONLY valid JSON on one line using double quotes. Do not add markdown, code fences, or any extra text. ',
      'The JSON must have three keys: {"theme":"","severity":"","suggested_action":""}. ',
      'Choose exactly ONE theme from: Illegal Parking | Abandoned Vehicle | Garbage Overflow | Illegal Dumping | Garbage Collection | Debris Removal | Mold/Mildew | Building Maintenance | Tree Maintenance | Vandalism | Noise Complaint | Flooding | Utility Complaint | Employee Conduct. ',
      'Severity must be one of "low","medium","high". ',
      'Write suggested_action as ONE imperative sentence. ',
      'Complaint Summary: ', t.summary
    ) AS prompt
  FROM todo t
)
SELECT
  service_request_id,
  summary,
  summary_source,
  ml_generate_text_llm_result AS triage_result,
  ml_generate_text_status AS status
FROM ML.GENERATE_TEXT(
  MODEL `@@PROJECT_ID@@.@@DATASET_ID@@.gemini_text`,
  TABLE prompts,
  STRUCT(0.0 AS temperature, 160 AS max_output_tokens, TRUE AS flatten_json_output)
);
