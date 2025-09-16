-- Creates a view to assess the quality of the raw text from user complaints.
CREATE OR REPLACE VIEW `@@PROJECT_ID@@.@@DATASET_ID@@.cases_text_quality` AS
WITH src AS (
  SELECT
    service_request_id,
    request_type,
    media_url,
    COALESCE(request_details, request_type) AS text_raw
  FROM `@@PROJECT_ID@@.@@DATASET_ID@@.cases_norm`
),
norm AS (
  SELECT
    service_request_id,
    request_type,
    media_url,
    TRIM(REGEXP_REPLACE(REPLACE(REPLACE(text_raw, "_", " "), "-", " "), r'\s+', ' ')) AS text_norm
  FROM src
)
SELECT
  service_request_id,
  request_type,
  media_url,
  text_norm,
  (media_url IS NOT NULL AND TRIM(media_url) <> "") AS has_media,
  (
    text_norm IS NULL OR text_norm = "" OR LENGTH(text_norm) < 5
    OR LOWER(text_norm) IN ("open","other","accepted","unknown","none","na","n/a")
  ) AS is_bad_text
FROM norm;


-- Creates a demo cohort table with a mix of good text and cases that need image analysis.
CREATE OR REPLACE TABLE `@@PROJECT_ID@@.@@DATASET_ID@@.batch_ids_demo` AS
WITH q AS (
  SELECT
    service_request_id,
    is_bad_text,
    has_media
  FROM `@@PROJECT_ID@@.@@DATASET_ID@@.cases_text_quality`
),
good AS (
  SELECT service_request_id FROM q
  WHERE is_bad_text = FALSE
  ORDER BY RAND()
  LIMIT 200
),
needs_img AS (
  SELECT service_request_id FROM q
  WHERE is_bad_text = TRUE AND has_media
  ORDER BY RAND()
  LIMIT 800
)
SELECT * FROM good
UNION ALL
SELECT * FROM needs_img;


-- Creates a pointer to the active cohort.
CREATE OR REPLACE TABLE `@@PROJECT_ID@@.@@DATASET_ID@@.batch_ids` AS
SELECT * FROM `@@PROJECT_ID@@.@@DATASET_ID@@.batch_ids_demo`;


-- Creates a table of fallback IDs for cases with bad text but available media.
CREATE OR REPLACE TABLE `@@PROJECT_ID@@.@@DATASET_ID@@.batch_fallback_ids` AS
SELECT
  q.service_request_id
FROM `@@PROJECT_ID@@.@@DATASET_ID@@.cases_text_quality` q
JOIN `@@PROJECT_ID@@.@@DATASET_ID@@.batch_ids` b USING (service_request_id)
WHERE q.is_bad_text = TRUE AND q.has_media = TRUE;
