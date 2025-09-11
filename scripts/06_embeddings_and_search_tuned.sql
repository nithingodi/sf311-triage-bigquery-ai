-- Project: City311 Multimodal Triage with BigQuery AI
-- Script: 06_embeddings_and_search_tuned.sql
-- Purpose:
--   Build theme-aware case embeddings and run a two-stage vector match:
--     (1) precise: policy.target_theme == case_theme
--     (2) global fallback: best overall if no precise match
-- Inputs:
--   - sf311.embed_text (REMOTE)
--   - sf311.batch_case_summaries
--   - sf311.batch_triage_raw_v2 (for parsed theme)
--   - sf311.policy_chunks  (catalog)
-- Outputs:
--   - TABLE sf311.policy_embeddings              (rebuilt)
--   - TABLE sf311.case_query_embeddings_v2       (rebuilt, includes theme)
--   - TABLE sf311._matches_all_vsearch           (top_k=5 pool)
--   - TABLE sf311.batch_policy_matches_precise   (top-1 theme-consistent)
--   - TABLE sf311.batch_policy_matches_global    (top-1 fallback)
--   - TABLE sf311.batch_policy_matches_v2        (union of precise + fallback)
-- Idempotency: CREATE OR REPLACE throughout (safe).
-- Notes:
--   - Uses COSINE distance; lower is better.
--   - Cutoff and top_k are parameterized below.

-- ===========
-- PARAMETERS
-- ===========
DECLARE project_id   STRING  DEFAULT 'sf311-triage-2025';
DECLARE dataset      STRING  DEFAULT 'sf311';
DECLARE embed_model  STRING  DEFAULT 'sf311-triage-2025.sf311.embed_text';
DECLARE top_k        INT64   DEFAULT 5;
DECLARE cutoff       FLOAT64 DEFAULT 0.50;  -- relaxed vs 0.40; tune to taste

-- 06_embeddings_and_search_tuned.sql (plain)
CREATE OR REPLACE TABLE `sf311-triage-2025.sf311.policy_embeddings` AS
SELECT policy_id, title, chunk_text, target_theme, source_url,
       ml_generate_embedding_result AS embedding
FROM ML.GENERATE_EMBEDDING(
  MODEL `sf311-triage-2025.sf311.embed_text`,
  (SELECT policy_id, title, chunk_text, target_theme, source_url, chunk_text AS content
   FROM `sf311-triage-2025.sf311.policy_chunks`),
  STRUCT(TRUE AS flatten_json_output)
);

CREATE OR REPLACE TABLE `sf311-triage-2025.sf311.case_query_embeddings_v2` AS
WITH parsed AS (
  SELECT r.service_request_id,
         COALESCE(JSON_VALUE(SAFE.PARSE_JSON(r.out_text),'$.theme'),'') AS theme,
         s.summary
  FROM `sf311-triage-2025.sf311.batch_triage_raw_v2` r
  JOIN `sf311-triage-2025.sf311.batch_case_summaries` s USING (service_request_id)
  WHERE s.summary IS NOT NULL
)
SELECT service_request_id, theme, summary,
       ml_generate_embedding_result AS embedding
FROM ML.GENERATE_EMBEDDING(
  MODEL `sf311-triage-2025.sf311.embed_text`,
  (SELECT service_request_id, theme, summary,
          CONCAT('Theme: ', theme, '. Summary: ', summary) AS content
   FROM parsed),
  STRUCT(TRUE AS flatten_json_output)
);

CREATE OR REPLACE TABLE `sf311-triage-2025.sf311._matches_all_vsearch` AS
SELECT
  vs.query.service_request_id,
  vs.query.theme            AS case_theme,
  vs.query.summary,
  vs.base.policy_id,
  vs.base.title             AS policy_title,
  vs.base.chunk_text        AS policy_snippet,
  vs.base.target_theme,
  vs.base.source_url,
  vs.distance               AS cosine_distance
FROM VECTOR_SEARCH(
  TABLE `sf311-triage-2025.sf311.policy_embeddings`,
  'embedding',
  TABLE `sf311-triage-2025.sf311.case_query_embeddings_v2`,
  top_k => 5,
  distance_type => 'COSINE'
) AS vs;

CREATE OR REPLACE TABLE `sf311-triage-2025.sf311.batch_policy_matches_precise` AS
SELECT * EXCEPT(rn)
FROM (
  SELECT m.*,
         ROW_NUMBER() OVER (PARTITION BY m.service_request_id ORDER BY m.cosine_distance) AS rn
  FROM `sf311-triage-2025.sf311._matches_all_vsearch` m
  WHERE LOWER(m.case_theme) = LOWER(m.target_theme)
)
WHERE rn = 1 AND cosine_distance <= 0.50;

CREATE OR REPLACE TABLE `sf311-triage-2025.sf311.batch_policy_matches_global` AS
SELECT * EXCEPT(rn)
FROM (
  SELECT m.*,
         ROW_NUMBER() OVER (PARTITION BY m.service_request_id ORDER BY m.cosine_distance) AS rn
  FROM `sf311-triage-2025.sf311._matches_all_vsearch` m
  WHERE m.service_request_id NOT IN (
    SELECT service_request_id FROM `sf311-triage-2025.sf311.batch_policy_matches_precise`
  )
)
WHERE rn = 1 AND cosine_distance <= 0.50;

CREATE OR REPLACE TABLE `sf311-triage-2025.sf311.batch_policy_matches_v2` AS
SELECT * FROM `sf311-triage-2025.sf311.batch_policy_matches_precise`
UNION ALL
SELECT * FROM `sf311-triage-2025.sf311.batch_policy_matches_global`;

