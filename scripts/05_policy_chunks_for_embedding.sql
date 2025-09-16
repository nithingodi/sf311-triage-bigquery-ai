-- 1) Normalize content to an intermediate table for embedding
CREATE OR REPLACE TABLE `@@PROJECT_ID@@.@@DATASET_ID@@.policy_chunks_for_embedding` AS
SELECT
  policy_id,
  TRIM(LOWER(chunk_text)) AS content
FROM `@@PROJECT_ID@@.@@DATASET_ID@@.policy_chunks`;
