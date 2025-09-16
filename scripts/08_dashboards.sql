-- Creates a view to power a pie chart showing the distribution of AI alignment results.
CREATE OR REPLACE VIEW `@@PROJECT_ID@@.@@DATASET_ID@@.v_alignment_pie` AS
SELECT
  alignment,
  COUNT(*) AS ct,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM `@@PROJECT_ID@@.@@DATASET_ID@@.batch_triage_policy_refined_v2`
GROUP BY alignment
ORDER BY ct DESC;

-- Creates a view to show examples of complaints where the AI's refined action
-- needs human review.
CREATE OR REPLACE VIEW `@@PROJECT_ID@@.@@DATASET_ID@@.v_mismatch_examples` AS
SELECT
  service_request_id,
  theme,
  severity,
  policy_title,
  source_url,
  original_action AS before_action,
  refined_action  AS after_action,
  alignment
FROM `@@PROJECT_ID@@.@@DATASET_ID@@.batch_triage_policy_refined_v2`
WHERE alignment = 'review' -- Corrected from 'mismatch-corrected' to match the data
ORDER BY service_request_id
LIMIT 25;
