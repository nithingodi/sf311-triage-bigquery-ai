-- Creates a view to count the rows in all key tables for a quick pipeline validation.
CREATE OR REPLACE VIEW `@@PROJECT_ID@@.@@DATASET_ID@@.v_validate_counts` AS
WITH t AS (
  SELECT '01_cases_norm' AS name, COUNT(*) AS n FROM `@@PROJECT_ID@@.@@DATASET_ID@@.cases_norm` UNION ALL
  SELECT '02_cases_for_classify', COUNT(*) FROM `@@PROJECT_ID@@.@@DATASET_ID@@.cases_for_classify` UNION ALL
  SELECT '03_cases_text_quality', COUNT(*) FROM `@@PROJECT_ID@@.@@DATASET_ID@@.cases_text_quality` UNION ALL
  SELECT '04_batch_ids', COUNT(*) FROM `@@PROJECT_ID@@.@@DATASET_ID@@.batch_ids` UNION ALL
  SELECT '05_batch_case_summaries', COUNT(*) FROM `@@PROJECT_ID@@.@@DATASET_ID@@.batch_case_summaries` UNION ALL
  SELECT '06_batch_triage_raw_v2', COUNT(*) FROM `@@PROJECT_ID@@.@@DATASET_ID@@.batch_triage_raw_v2` UNION ALL
  SELECT '07_policy_chunks', COUNT(*) FROM `@@PROJECT_ID@@.@@DATASET_ID@@.policy_chunks` UNION ALL
  SELECT '08_policy_embeddings', COUNT(*) FROM `@@PROJECT_ID@@.@@DATASET_ID@@.policy_embeddings` UNION ALL
  SELECT '09_case_query_embeddings_v2', COUNT(*) FROM `@@PROJECT_ID@@.@@DATASET_ID@@.case_query_embeddings_v2` UNION ALL
  SELECT '10_batch_policy_matches_v2', COUNT(*) FROM `@@PROJECT_ID@@.@@DATASET_ID@@.batch_policy_matches_v2` UNION ALL
  SELECT '11_batch_triage_policy_refined_v2', COUNT(*) FROM `@@PROJECT_ID@@.@@DATASET_ID@@.batch_triage_policy_refined_v2`
)
SELECT * FROM t ORDER BY name;

-- Creates a view to check the health of the JSON output from the triage model.
CREATE OR REPLACE VIEW `@@PROJECT_ID@@.@@DATASET_ID@@.v_validate_json` AS
SELECT
  COUNTIF(triage_result IS NULL) AS bad_json_rows,
  COUNT(*) AS total_rows
FROM `@@PROJECT_ID@@.@@DATASET_ID@@.batch_triage_raw_v2`;

-- Creates a view to show the distribution of the final alignment results.
CREATE OR REPLACE VIEW `@@PROJECT_ID@@.@@DATASET_ID@@.v_validate_alignment` AS
SELECT
  alignment,
  COUNT(*) AS ct,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM `@@PROJECT_ID@@.@@DATASET_ID@@.batch_triage_policy_refined_v2`
GROUP BY alignment
ORDER BY ct DESC;
