-- Creates embeddings for the policy catalog.
CREATE OR REPLACE TABLE `@@PROJECT_ID@@.@@DATASET_ID@@.policy_embeddings` AS
SELECT
  policy_id,
  title,
  chunk_text,
  target_theme,
  source_url,
  ml_generate_embedding_result AS embedding
FROM ML.GENERATE_EMBEDDING(
  MODEL `@@PROJECT_ID@@.@@DATASET_ID@@.embed_text`,
  (
    SELECT policy_id, title, chunk_text, target_theme, source_url, chunk_text AS content
    FROM `@@PROJECT_ID@@.@@DATASET_ID@@.policy_chunks`
  ),
  STRUCT(TRUE AS flatten_json_output)
);

-- Creates theme-aware embeddings for each user complaint.
CREATE OR REPLACE TABLE `@@PROJECT_ID@@.@@DATASET_ID@@.case_query_embeddings_v2` AS
WITH parsed AS (
  SELECT
    r.service_request_id,
    COALESCE(JSON_VALUE(triage_result, '$.theme'), '') AS theme,
    s.summary
  FROM `@@PROJECT_ID@@.@@DATASET_ID@@.batch_triage_raw_v2` AS r
  JOIN `@@PROJECT_ID@@.@@DATASET_ID@@.batch_case_summaries` AS s USING (service_request_id)
  WHERE s.summary IS NOT NULL
)
SELECT
  service_request_id,
  theme,
  summary,
  ml_generate_embedding_result AS embedding
FROM ML.GENERATE_EMBEDDING(
  MODEL `@@PROJECT_ID@@.@@DATASET_ID@@.embed_text`,
  (
    SELECT
      service_request_id,
      theme,
      summary,
      CONCAT('Theme: ', theme, '. Summary: ', summary) AS content
    FROM parsed
  ),
  STRUCT(TRUE AS flatten_json_output)
);

-- Performs a vector search to find the top 5 potential policy matches for each case.
CREATE OR REPLACE TABLE `@@PROJECT_ID@@.@@DATASET_ID@@._matches_all_vsearch` AS
SELECT
  vs.query.service_request_id,
  vs.query.theme AS case_theme,
  vs.query.summary,
  vs.base.policy_id,
  vs.base.title AS policy_title,
  vs.base.chunk_text AS policy_snippet,
  vs.base.target_theme,
  vs.base.source_url,
  vs.distance AS cosine_distance
FROM VECTOR_SEARCH(
  TABLE `@@PROJECT_ID@@.@@DATASET_ID@@.policy_embeddings`,
  'embedding',
  TABLE `@@PROJECT_ID@@.@@DATASET_ID@@.case_query_embeddings_v2`,
  'embedding',
  top_k => 5,
  distance_type => 'COSINE'
);

-- Finds the best match where the AI-generated theme matches the policy's theme.
CREATE OR REPLACE TABLE `@@PROJECT_ID@@.@@DATASET_ID@@.batch_policy_matches_precise` AS
SELECT * EXCEPT(rn)
FROM (
  SELECT
    m.*,
    ROW_NUMBER() OVER (PARTITION BY m.service_request_id ORDER BY m.cosine_distance) AS rn
  FROM `@@PROJECT_ID@@.@@DATASET_ID@@._matches_all_vsearch` AS m
  WHERE LOWER(m.case_theme) = LOWER(m.target_theme)
)
WHERE rn = 1 AND cosine_distance <= 0.50;

-- Finds the best overall match for cases that didn't have a precise theme match.
CREATE OR REPLACE TABLE `@@PROJECT_ID@@.@@DATASET_ID@@.batch_policy_matches_global` AS
SELECT * EXCEPT(rn)
FROM (
  SELECT
    m.*,
    ROW_NUMBER() OVER (PARTITION BY m.service_request_id ORDER BY m.cosine_distance) AS rn
  FROM `@@PROJECT_ID@@.@@DATASET_ID@@._matches_all_vsearch` AS m
  WHERE m.service_request_id NOT IN (
    SELECT service_request_id FROM `@@PROJECT_ID@@.@@DATASET_ID@@.batch_policy_matches_precise`
  )
)
WHERE rn = 1 AND cosine_distance <= 0.50;

-- Combines the precise and global matches into a final table.
CREATE OR REPLACE TABLE `@@PROJECT_ID@@.@@DATASET_ID@@.batch_policy_matches_v2` AS
SELECT * FROM `@@PROJECT_ID@@.@@DATASET_ID@@.batch_policy_matches_precise`
UNION ALL
SELECT * FROM `@@PROJECT_ID@@.@@DATASET_ID@@.batch_policy_matches_global`;
