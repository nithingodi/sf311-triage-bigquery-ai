-- Project: City311 Multimodal Triage with BigQuery AI
-- Script: 04_triage_generate.sql
-- Purpose: Use an LLM (REMOTE model) to produce triage JSON:
--          {"theme":"","severity":"","suggested_action":""}
-- Inputs:  sf311.batch_case_summaries, sf311.gemini_text (REMOTE)
-- Outputs: TABLE sf311.batch_triage_raw (service_request_id, summary, summary_source, out_text, status)
-- Idempotency: Table is created if missing; INSERT skips already-processed IDs; throttle for demo runs.
-- Next: 05_policies.sql (policy catalog), 06_matching.sql (embeddings + vector search)

-- ===========
-- PARAMETERS
-- ===========
DECLARE project_id    STRING DEFAULT 'sf311-triage-2025';
DECLARE dataset       STRING DEFAULT 'sf311';
DECLARE model_path    STRING DEFAULT 'sf311-triage-2025.sf311.gemini_text';
DECLARE insert_limit  INT64  DEFAULT 500;  -- throttle for demo; raise/remove for full run

-- ======================================
-- Create results table (once) if missing
-- ======================================
EXECUTE IMMEDIATE FORMAT("""
  CREATE TABLE IF NOT EXISTS `%s.%s.batch_triage_raw` (
    service_request_id STRING,
    summary            STRING,
    summary_source     STRING,
    out_text           STRING,  -- raw model output (expected single-line JSON)
    status             STRING   -- BigQuery ML status text
  )
""", project_id, dataset);

-- ===========================================================
-- Prepare prompts for cases needing triage; skip those already
-- present in results. Keep a limit for demo control.
-- ===========================================================
EXECUTE IMMEDIATE FORMAT("""
  INSERT INTO `%s.%s.batch_triage_raw` (service_request_id, summary, summary_source, out_text, status)
  WITH s AS (
    SELECT service_request_id, summary, summary_source
    FROM `%s.%s.batch_case_summaries`
    WHERE summary IS NOT NULL
  ),
  todo AS (
    SELECT s.*
    FROM s
    LEFT JOIN `%s.%s.batch_triage_raw` r USING (service_request_id)
    WHERE r.service_request_id IS NULL
    LIMIT %d
  ),
  prompts AS (
    SELECT
      service_request_id,
      summary,
      summary_source,
      CONCAT(
        'You are a city 311 triage bot. Respond with ONLY valid JSON on one line: ',
        '{\"theme\":\"\",\"severity\":\"\",\"suggested_action\":\"\"}',
        ' Use double quotes. No markdown, no code fences, no extra text. ',
        'Choose exactly ONE theme from: ',
        'Illegal Parking | Abandoned Vehicle | Garbage Overflow | Illegal Dumping | Garbage Collection | ',
        'Debris Removal | Mold/Mildew | Building Maintenance | Tree Maintenance | Vandalism | ',
        'Noise Complaint | Flooding | Utility Complaint | Employee Conduct. ',
        'Severity must be one of \"low\",\"medium\",\"high\". ',
        'Write suggested_action as ONE imperative sentence. ',
        'Summary: ', summary
      ) AS prompt
    FROM todo
  )
  SELECT
    service_request_id,
    summary,
    summary_source,
    -- Normalize output to a single line; strip code fences if any
    REGEXP_REPLACE(REPLACE(ml_generate_text_llm_result, '\\n', ''), r'```[a-z]*|```', '') AS out_text,
    ml_generate_text_status AS status
  FROM ML.GENERATE_TEXT(
    MODEL %s,
    TABLE prompts,
    STRUCT(
      0.0 AS temperature,
      160  AS max_output_tokens,
      TRUE AS flatten_json_output
    )
  )
""",
  project_id, dataset,
  project_id, dataset,
  project_id, dataset,
  insert_limit,
  model_path
);
