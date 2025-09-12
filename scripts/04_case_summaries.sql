-- 04_case_summaries.sql
-- Build per-case summary view

DECLARE project_id STRING DEFAULT "${PROJECT_ID}";
DECLARE dataset    STRING DEFAULT "${DATASET}";

EXECUTE IMMEDIATE
'CREATE OR REPLACE VIEW `' || project_id || '.' || dataset || '.batch_case_summaries` AS
WITH ids AS (
  SELECT service_request_id FROM `' || project_id || '.' || dataset || '.batch_ids`
),
text_src AS (
  SELECT c.service_request_id, cf.complaint_text, q.is_bad_text
  FROM ids c
  JOIN `' || project_id || '.' || dataset || '.cases_for_classify` cf USING (service_request_id)
  JOIN `' || project_id || '.' || dataset || '.cases_text_quality` q USING (service_request_id)
),
img_src AS (
  SELECT service_request_id, summary_text AS image_summary
  FROM `' || project_id || '.' || dataset || '.batch_image_summaries`
)
SELECT
  i.service_request_id,
  CASE
    WHEN t.is_bad_text = FALSE THEN t.complaint_text
    WHEN i2.image_summary IS NOT NULL THEN i2.image_summary
    ELSE NULL
  END AS summary,
  CASE
    WHEN t.is_bad_text = FALSE THEN "text"
    WHEN i2.image_summary IS NOT NULL THEN "image"
    ELSE "none"
  END AS summary_source
FROM ids i
JOIN text_src t USING (service_request_id)
LEFT JOIN img_src i2 USING (service_request_id)';
