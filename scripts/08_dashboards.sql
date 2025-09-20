-- Creates a view to power a pie chart showing the distribution of AI alignment results.
CREATE OR REPLACE VIEW `sf311-triage-2025.sf311.v_alignment_pie` AS
SELECT
  alignment,
  COUNT(*) AS ct,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM `sf311-triage-2025.sf311.batch_triage_policy_refined_v2`
GROUP BY alignment
ORDER BY ct DESC;

-- Creates a view to show examples of complaints where the AI's refined action
-- needs human review, without a limit.
CREATE OR REPLACE VIEW `sf311-triage-2025.sf311.v_mismatch_examples` AS
SELECT
  service_request_id,
  theme,
  severity,
  policy_title,
  source_url,
  original_action AS before_action,
  refined_action  AS after_action,
  alignment
FROM `sf311-triage-2025.sf311.batch_triage_policy_refined_v2`
WHERE alignment = 'review'
ORDER BY service_request_id;
