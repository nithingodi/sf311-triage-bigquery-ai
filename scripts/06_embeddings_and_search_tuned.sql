-- Project: City311 Multimodal Triage with BigQuery AI
-- Script: 06_embeddings_and_search_tuned.sql
-- Purpose:
--   Build theme-aware case embeddings and run a two-stage vector match
-- Inputs:
--   embed_text model, batch_case_summaries, batch_triage_raw_v2, policy_chunks
-- Outputs:
--   policy_embeddings, case_query_embeddings_v2, _matches_all_vsearch,
--   batch_policy_matches_precise, batch_policy_matches_global, batch_policy_matches_v2
-- Idempotency: CREATE OR REPLACE (safe)

-- ===========
-- PARAMETERS
-- ===========
DECLARE project_id  STRING  DEFAULT "@PROJECT_ID";
DECLARE dataset     STRING  DEFAULT "@DATASET";
DECLARE top_k       INT64   DEFAULT 5;
DECLARE cutoff      FLOAT64 DEFAULT 0.50;

-- ==========================================================
-- Policy embeddings
-- ==========================================================
EXECUTE IMMEDIATE FORMAT("""
CREATE OR REPLACE TABLE `%s.%s.policy_embeddings` AS
SELECT policy_id, title, chunk_text, target_theme, source_url,
       ml_generate_embedding_result AS embedding
FROM ML.GENERATE_EMBEDDING(
  MODEL `%s.%s.embed_text`,
  (SELECT policy_id, title, chunk_text, target_theme, source_url, chunk_text AS content
   FROM `%s.%s.policy_chunks`),
  STRUCT(TRUE AS flatten_json_output)
);
""", project_id, dataset, project_id, dataset, project_id, dataset);

-- ==========================================================
-- Case embeddings
-- ==========================================================
EXECUTE IMMEDIATE FORMAT("""
CREATE OR REPLACE TABLE `%s.%s.case_query_embeddings_v2` AS
WITH parsed AS (
  SELECT r.service_request_id,
         COALESCE(JSON_VALUE(SAFE.PARSE_JSON(r.out_text),'$.theme'),'') AS theme,
         s.summary
  FROM `%s.%s.batch_triage_raw_v2` r
  JOIN `%s.%s.batch_case_summaries` s USING (service_request_id)
  WHERE s.summary IS NOT NULL
)
SELECT service_request_id, theme, summary,
       ml_generate_embedding_result AS embedding
FROM ML.GENERATE_EMBEDDING(
  MODEL `%s.%s.embed_text`,
  (SELECT service_request_id, theme, summary,
          CONCAT('Theme: ', theme, '. Summary: ', summary) AS content
   FROM parsed),
  STRUCT(TRUE AS flatten_json_output)
);
""", project_id, dataset,
     project_id, dataset,
     project_id, dataset,
     project_id, dataset);

-- ==========================================================
-- Vector search matches (pool)
-- ==========================================================
EXECUTE IMMEDIATE FORMAT("""
CREATE OR REPLACE TABLE `%s.%s._matches_all_vsearch` AS
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
  TABLE `%s.%s.policy_embeddings`,
  'embedding',
  TABLE `%s.%s.case_query_embeddings_v2`,
  top_k => %d,
  distance_type => 'COSINE'
) AS vs;
""", project_id, dataset,
     project_id, dataset,
     project_id, dataset,
     top_k);

-- ==========================================================
-- Precise theme-consistent matches
-- ==========================================================
EXECUTE IMMEDIATE FORMAT("""
CREATE OR REPLACE TABLE `%s.%s.batch_policy_matches_precise` AS
SELECT * EXCEPT(rn)
FROM (
  SELECT m.*,
         ROW_NUMBER() OVER (PARTITION BY m.service_request_id ORDER BY m.cosine_distance) AS rn
  FROM `%s.%s._matches_all_vsearch` m
  WHERE LOWER(m.case_theme) = LOWER(m.target_theme)
)
WHERE rn = 1 AND cosine_distance <= %f;
""", project_id, dataset,
     project_id, dataset,
     cutoff);

-- ==========================================================
-- Global fallback matches
-- ==========================================================
EXECUTE IMMEDIATE FORMAT("""
CREATE OR REPLACE TABLE `%s.%s.batch_policy_matches_global` AS
SELECT * EXCEPT(rn)
FROM (
  SELECT m.*,
         ROW_NUMBER() OVER (PARTITION BY m.service_request_id ORDER BY m.cosine_distance) AS rn
  FROM `%s.%s._matches_all_vsearch` m
  WHERE m.service_request_id NOT IN (
    SELECT service_request_id FROM `%s.%s.batch_policy_matches_precise`
  )
)
WHERE rn = 1 AND cosine_distance <= %f;
""", project_id, dataset,
     project_id, dataset,
     project_id, dataset,
     cutoff);

-- ==========================================================
-- Union of precise + fallback
-- ==========================================================
EXECUTE IMMEDIATE FORMAT("""
CREATE OR REPLACE TABLE `%s.%s.batch_policy_matches_v2` AS
SELECT * FROM `%s.%s.batch_policy_matches_precise`
UNION ALL
SELECT * FROM `%s.%s.batch_policy_matches_global`;
""", project_id, dataset,
     project_id, dataset,
     project_id, dataset);
