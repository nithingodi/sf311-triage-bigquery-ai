-- Creates a view that provides a final summary for each case,
-- using either the original text or the AI-generated image summary.
CREATE OR REPLACE VIEW `@@PROJECT_ID@@.@@DATASET_ID@@.batch_case_summaries` AS
WITH text_source AS (
  SELECT
    c.service_request_id,
    cf.complaint_text,
    q.is_bad_text
  FROM `@@PROJECT_ID@@.@@DATASET_ID@@.batch_ids` AS c
  JOIN `@@PROJECT_ID@@.@@DATASET_ID@@.cases_for_classify` AS cf USING (service_request_id)
  JOIN `@@PROJECT_ID@@.@@DATASET_ID@@.cases_text_quality` AS q USING (service_request_id)
),
image_source AS (
  SELECT
    service_request_id,
    -- Extract the text result from AI.GENERATE output
    summary_text AS image_summary
  FROM `@@PROJECT_ID@@.@@DATASET_ID@@.batch_image_summaries`
)
SELECT
  t.service_request_id,
  CASE
    WHEN NOT t.is_bad_text THEN t.complaint_text
    WHEN t.is_bad_text AND i.image_summary IS NOT NULL THEN i.image_summary
    ELSE NULL
  END AS summary,
  CASE
    WHEN NOT t.is_bad_text THEN "text"
    WHEN t.is_bad_text AND i.image_summary IS NOT NULL THEN "image"
    ELSE "none"
  END AS summary_source
FROM text_source AS t
LEFT JOIN image_source AS i USING (service_request_id);
