-- 2) Generate embeddings for each policy chunk
CREATE OR REPLACE TABLE `@@PROJECT_ID@@.@@DATASET_ID@@.policy_embeddings` AS
SELECT
  policy_id,
  content,
  ml_generate_embedding_result AS embedding
FROM ML.GENERATE_EMBEDDING(
  MODEL `@@PROJECT_ID@@.@@DATASET_ID@@.embed_text`,
  TABLE `@@PROJECT_ID@@.@@DATASET_ID@@.policy_chunks_for_embedding`
) AS tvf;
