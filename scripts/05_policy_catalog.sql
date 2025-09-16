-- 3) Build the final policy_catalog, preserving all original columns
CREATE OR REPLACE TABLE `@@PROJECT_ID@@.@@DATASET_ID@@.policy_catalog` AS
SELECT
  pc.* EXCEPT(chunk_text),
  pe.content,
  pe.embedding
FROM `@@PROJECT_ID@@.@@DATASET_ID@@.policy_chunks` pc
LEFT JOIN `@@PROJECT_ID@@.@@DATASET_ID@@.policy_embeddings` pe
ON pe.policy_id = pc.policy_id;
