-- Project: City311 Multimodal Triage with BigQuery AI
-- Script: 04_triage_generate_v2.sql
-- Purpose: LLM triage using a dynamic taxonomy sourced from sf311.label_taxonomy.
-- Inputs:  sf311.batch_case_summaries, sf311.label_taxonomy, sf311.gemini_text (REMOTE)
-- Outputs: TABLE sf311.batch_triage_raw_v2 (service_request_id, summary, summary_source, out_text, status)
-- Idempotency: Table created if missing; INSERT skips already-processed IDs; throttle for demo.
-- Next: parsing/validation into structured columns (theme, severity, suggested_action).

DECLARE project_id     STRING DEFAULT 'sf311-triage-2025';
DECLARE dataset        STRING DEFAULT 'sf311';
DECLARE model_path     STRING DEFAULT 'sf311-triage-2025.sf311.gemini_text';
DECLARE insert_limit   INT64  DEFAULT 500;

-- Create results table if missing
EXECUTE IMMEDIATE FORMAT("""
  CREATE TABLE IF NOT EXISTS `%s.%s.batch_triage_raw_v2` (
    service_request_id STRING,
    summary            STRING,
    summary_source     STRING,
    out_text           STRING,
    status             STRING
  )
""", project_id, dataset);

-- Insert new triage results using a dynamic label list
EXECUTE IMMEDIATE FORMAT("""
  INSERT INTO `%s.%s.batch_triage_raw_v2`
  (service_request_id, summary, summary_source, out_text, status)
  WITH labels AS (
    SELECT STRING_AGG(theme, ' | ' ORDER BY theme) AS label_list
    FROM `%s.%s.label_taxonomy`
  ),
  s AS (
    SELECT service_request_id, summary, summary_source
    FROM `%s.%s.batch_case_summaries`
    WHERE summary IS NOT NULL
  ),
  todo AS (
    SELECT s.*
    FROM s
    LEFT JOIN `%s.%s.batch_triage_raw_v2` r USING (service_request_id)
    WHERE r.service_request_id IS NULL
    LIMIT %d
  ),
  prompts AS (
    SELECT
      t.service_request_id, t.summary, t.summary_source, l.label_list,
      CONCAT(
        'You are a city 311 triage bot. Respond with ONLY valid JSON on one line: ',
        '{\"theme\":\"\",\"severity\":\"\",\"suggested_action\":\"\"}',
        ' Use double quotes. No markdown, no code fences, no extra text. ',
        'Choose exactly ONE theme from this list (copy text exactly): ',
        l.label_list, '. ',
        'Severity must be one of \"low\",\"medium\",\"high\". ',
        'Write suggested_action as ONE imperative sentence. ',
        'Summary: ', t.summary
      ) AS prompt
    FROM todo t CROSS JOIN labels l
  )
  SELECT
    service_request_id,
    summary,
    summary_source,
    REGEXP_REPLACE(REPLACE(ml_generate_text_llm_result, '\\n', ''), r'```[a-z]*|```', '') AS out_text,
    ml_generate_text_status AS status
  FROM ML.GENERATE_TEXT(
    MODEL %s,
    TABLE prompts,
    STRUCT(0.0 AS temperature, 160 AS max_output_tokens, TRUE AS flatten_json_output)
  )
""",
  project_id, dataset,
  project_id, dataset,
  project_id, dataset,
  project_id, dataset, insert_limit,
  model_path
);
