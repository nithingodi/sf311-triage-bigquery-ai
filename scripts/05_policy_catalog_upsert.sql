-- This script demonstrates an upsert (update or insert) operation using a MERGE statement.
-- It adds a new policy or updates the embedding for an existing one.
MERGE `@@PROJECT_ID@@.@@DATASET_ID@@.policy_catalog` T
USING (
  SELECT
    "1" AS policy_id,
    "SFMTA" AS agency,
    "Muni" AS category,
    "General inquiries and feedback about Muni service." AS policy_summary,
    ML.GENERATE_EMBEDDING(
      MODEL `@@PROJECT_ID@@.@@DATASET_ID@@.embed_text`,
      (SELECT "General inquiries and feedback about Muni service." AS content)
    ).embedding AS embedding
) S
ON T.policy_id = S.policy_id
WHEN MATCHED THEN
  UPDATE SET
    T.agency = S.agency,
    T.category = S.category,
    T.policy_summary = S.policy_summary,
    T.embedding = S.embedding
WHEN NOT MATCHED THEN
  INSERT (policy_id, agency, category, policy_summary, embedding)
  VALUES (S.policy_id, S.agency, S.category, S.policy_summary, S.embedding);
