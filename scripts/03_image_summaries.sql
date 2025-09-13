DECLARE project_id   STRING DEFAULT "${PROJECT_ID}";
DECLARE dataset      STRING DEFAULT "${DATASET}";
DECLARE location     STRING DEFAULT "${LOCATION}";
DECLARE gem_conn_id  STRING DEFAULT "${CONN}";
DECLARE gen_endpoint STRING DEFAULT "gemini-2.0-flash-001";

EXECUTE IMMEDIATE
'INSERT INTO `' || project_id || '.' || dataset || '.batch_image_summaries` (service_request_id, summary_text)
WITH fallback_ext AS (
  SELECT CAST(n.service_request_id AS STRING) AS service_request_id, n.media_url AS url
  FROM `' || project_id || '.' || dataset || '.batch_fallback_ids` b
  JOIN `' || project_id || '.' || dataset || '.cases_norm` n USING (service_request_id)
  WHERE n.media_url IS NOT NULL AND TRIM(n.media_url) <> ""
    AND REGEXP_CONTAINS(LOWER(n.media_url), r"\.(jpg|jpeg|png|gif)(?:$|[?#])")
),
todo AS (
  SELECT f.service_request_id, f.url
  FROM fallback_ext f
  LEFT JOIN `' || project_id || '.' || dataset || '.batch_image_summaries` s USING (service_request_id)
  WHERE s.service_request_id IS NULL
  LIMIT 200
)
SELECT
  service_request_id,
  AI.GENERATE(
    ("Summarize this SF311 complaint photo in one concise sentence (<= 30 words). Return only the sentence.", url),
    connection_id => "projects/" || project_id || "/locations/" || location || "/connections/" || gem_conn_id,
    endpoint      => gen_endpoint,
    model_params  => JSON ''{"generation_config":{"temperature":0}}''
  ).result AS summary_text
FROM todo';
