-- 1) Ensures the destination table exists with the correct schema.
CREATE TABLE IF NOT EXISTS `@@PROJECT_ID@@.@@DATASET_ID@@.batch_triage_raw_v2` (
  service_request_id STRING,
  summary STRING,
  summary_source STRING,
  triage_result STRING,
  status STRING
);

-- 2) Inserts new records into the table with a corrected JOIN.
INSERT INTO `@@PROJECT_ID@@.@@DATASET_ID@@.batch_triage_raw_v2`
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
),
prompts AS (
  SELECT
    t.service_request_id, t.summary, t.summary_source,
    -- Add a unique identifier to the prompt for a safe join
    CONCAT(
      'Complaint Summary: ', t.summary,
      ' | You are a city 311 triage bot. Respond with ONLY valid JSON on one line using double quotes. Do not add markdown, code fences, or any extra text. ',
      'The JSON must have three keys: {"theme":"","severity":"","suggested_action":""}. ',
      'Choose exactly ONE theme from: Illegal Parking | Abandoned Vehicle | Garbage Overflow | Illegal Dumping | Garbage Collection | Debris Removal | Mold/Mildew | Building Maintenance | Tree Maintenance | Vandalism | Noise Complaint | Flooding | Utility Complaint | Employee Conduct. ',
      'Severity must be one of "low","medium","high". ',
      'Write suggested_action as ONE imperative sentence. ',
      'Internal ID: ', t.service_request_id -- Add unique ID here
    ) AS prompt,
    t.service_request_id AS original_service_request_id -- Carry the ID forward
  FROM todo t
),
results AS (
  SELECT
    prompt,
    ml_generate_text_llm_result AS triage_result,
    ml_generate_text_status AS status
  FROM ML.GENERATE_TEXT(
    MODEL `@@PROJECT_ID@@.@@DATASET_ID@@.gemini_text`,
    TABLE prompts,
    STRUCT(0.0 AS temperature, 160 AS max_output_tokens, TRUE AS flatten_json_output)
  )
)
SELECT
  p.original_service_request_id,
  p.summary,
  p.summary_source,
  r.triage_result,
  r.status
FROM results r
-- CORRECTED JOIN: Use the prompt and the unique ID to ensure a 1-to-1 match
JOIN prompts p ON r.prompt = p.prompt AND p.original_service_request_id IS NOT NULL;
