DECLARE project_id STRING DEFAULT "${PROJECT_ID}";
DECLARE dataset    STRING DEFAULT "${DATASET}";

-- Text quality view
EXECUTE IMMEDIATE FORMAT("""
CREATE OR REPLACE VIEW `%s.%s.cases_text_quality` AS
WITH src AS (
  SELECT service_request_id, request_type, media_url,
         COALESCE(request_details, request_type) AS text_raw
  FROM `%s.%s.cases_norm`
),
norm AS (
  SELECT service_request_id, request_type, media_url,
         TRIM(REGEXP_REPLACE(REPLACE(REPLACE(text_raw,'_',' '),'-',' '), r'\\s+', ' ')) AS text_norm
  FROM src
)
SELECT
  service_request_id, request_type, media_url, text_norm,
  (media_url IS NOT NULL AND TRIM(media_url) <> '') AS has_media,
  (text_norm IS NULL OR text_norm = '' OR LENGTH(text_norm) < 5 OR LOWER(text_norm) IN ('open','other','accepted','unknown','none','na','n/a')) AS is_bad_text
FROM norm;
""", project_id, dataset, project_id, dataset);

-- Tables batch_ids_demo, batch_ids, batch_fallback_ids (same FORMAT)
