-- 10_validation.sql
CREATE OR REPLACE VIEW `sf311-triage-2025.sf311.v_validate_counts` AS
WITH t AS (
  SELECT 'cases_norm' AS name, COUNT(*) AS n FROM `sf311-triage-2025.sf311.cases_norm`
  UNION ALL SELECT 'cases_for_classify', COUNT(*) FROM `sf311-triage-2025.sf311.cases_for_classify`
  UNION ALL SELECT 'cases_text_quality', COUNT(*) FROM `sf311-triage-2025.sf311.cases_text_quality`
  UNION ALL SELECT 'batch_ids', COUNT(*) FROM `sf311-triage-2025.sf311.batch_ids`
  UNION ALL SELECT 'batch_case_summaries', COUNT(*) FROM `sf311-triage-2025.sf311.batch_case_summaries`
  UNION ALL SELECT 'batch_triage_raw_v2', COUNT(*) FROM `sf311-triage-2025.sf311.batch_triage_raw_v2`
  UNION ALL SELECT 'policy_chunks', COUNT(*) FROM `sf311-triage-2025.sf311.policy_chunks`
  UNION ALL SELECT 'policy_embeddings', COUNT(*) FROM `sf311-triage-2025.sf311.policy_embeddings`
  UNION ALL SELECT 'case_query_embeddings_v2', COUNT(*) FROM `sf311-triage-2025.sf311.case_query_embeddings_v2`
  UNION ALL SELECT 'batch_policy_matches_v2', COUNT(*) FROM `sf311-triage-2025.sf311.batch_policy_matches_v2`
  UNION ALL SELECT 'batch_triage_policy_refined_v2', COUNT(*) FROM `sf311-triage-2025.sf311.batch_triage_policy_refined_v2`
)
SELECT * FROM t ORDER BY name;

CREATE OR REPLACE VIEW `sf311-triage-2025.sf311.v_validate_json` AS
SELECT
  COUNTIF(SAFE.PARSE_JSON(out_text) IS NULL) AS bad_json_rows,
  COUNT(*) AS total_rows
FROM `sf311-triage-2025.sf311.batch_triage_raw_v2`;

CREATE OR REPLACE VIEW `sf311-triage-2025.sf311.v_validate_alignment` AS
SELECT alignment, COUNT(*) ct,
       ROUND(100*COUNT(*)/SUM(COUNT(*)) OVER (),1) pct
FROM `sf311-triage-2025.sf311.batch_triage_policy_refined_v2`
GROUP BY alignment
ORDER BY ct DESC;
