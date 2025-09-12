DECLARE project_id STRING DEFAULT "${PROJECT_ID}";
DECLARE dataset    STRING DEFAULT "${DATASET}";

-- Normalized case view
EXECUTE IMMEDIATE FORMAT("""
CREATE OR REPLACE VIEW `%s.%s.cases_norm` AS
SELECT
  CAST(unique_key AS STRING) AS service_request_id,
  created_date AS requested_datetime,
  COALESCE(complaint_type, category) AS request_type,
  COALESCE(descriptor, status_notes, complaint_type) AS request_details,
  agency_name AS agency_responsible,
  media_url
FROM `bigquery-public-data.san_francisco_311.311_service_requests`;
""", project_id, dataset);

-- Cleaned text view
EXECUTE IMMEDIATE FORMAT("""
CREATE OR REPLACE VIEW `%s.%s.cases_for_classify` AS
WITH raw AS (
  SELECT service_request_id, request_type,
         COALESCE(request_details, request_type) AS txt
  FROM `%s.%s.cases_norm`
  WHERE COALESCE(request_details, request_type) IS NOT NULL
),
deboil AS (
  SELECT service_request_id, request_type,
    REGEXP_REPLACE(
      REGEXP_REPLACE(
        REGEXP_REPLACE(txt, r'(?i)\\bcase\\s+transferred.*$', ''),
        r'(?i)\\bcase\\s+is\\s+a\\s+duplicate.*$', ''),
      r'(?i)customer may follow up.*$', ''
    ) AS txt
  FROM raw
),
norm AS (
  SELECT service_request_id, request_type,
    TRIM(REGEXP_REPLACE(REPLACE(REPLACE(txt, '_', ' '), '-', ' '), r'\\s+', ' ')) AS txt0
  FROM deboil
)
SELECT
  service_request_id,
  CASE
    WHEN LOWER(txt0) IN ('open','other','accepted','unknown','none','na','n/a') OR LENGTH(txt0) < 5
      THEN CONCAT('(', INITCAP(COALESCE(request_type, 'Issue')), ') No detailed text provided.')
    ELSE CASE
           WHEN REGEXP_CONTAINS(INITCAP(txt0), r'[.!?]\\s*$') THEN INITCAP(txt0)
           ELSE CONCAT(INITCAP(txt0), '.')
         END
  END AS complaint_text
FROM norm;
""", project_id, dataset, project_id, dataset);
