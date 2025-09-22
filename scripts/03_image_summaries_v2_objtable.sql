-- This is the alternate version of the image summarization script.
-- It uses the Object Table to ensure reliable access to GCS images.

-- Ensure the destination table exists
CREATE TABLE IF NOT EXISTS `@@PROJECT_ID@@.@@DATASET_ID@@.batch_image_summaries`
(service_request_id STRING, summary_text STRING);

-- Insert new summaries
INSERT INTO `@@PROJECT_ID@@.@@DATASET_ID@@.batch_image_summaries` (service_request_id, summary_text)
WITH
  -- Get the list of images that need summarization
  fallback_ids AS (
    SELECT
      q.service_request_id
    FROM `@@PROJECT_ID@@.@@DATASET_ID@@.cases_text_quality` AS q
    JOIN `@@PROJECT_ID@@.@@DATASET_ID@@.batch_ids` AS b USING (service_request_id)
    WHERE q.is_bad_text = TRUE AND q.has_media = TRUE
  ),
  -- Get the gs:// URIs from the Object Table for those IDs
  image_uris AS (
    SELECT
      obj.uri,
      REGEXP_EXTRACT(obj.uri, r'(\d+)\.jpg$') AS service_request_id
    FROM
      `@@PROJECT_ID@@.@@DATASET_ID@@.images_obj_cohort` AS obj
    -- Filter for only the IDs that are in our fallback list
    WHERE REGEXP_EXTRACT(obj.uri, r'(\d+)\.jpg$') IN (SELECT service_request_id FROM fallback_ids)
  ),
  -- Ensure we don't re-process images we've already done
  todo AS (
    SELECT u.service_request_id, u.uri
    FROM image_uris AS u
    LEFT JOIN `@@PROJECT_ID@@.@@DATASET_ID@@.batch_image_summaries` AS s USING (service_request_id)
    WHERE s.service_request_id IS NULL
  )
SELECT
  service_request_id,
  AI.GENERATE(
    (
      'Summarize this SF311 complaint photo in one concise sentence (<= 30 words). Return only the sentence.',
      -- Use the reliable gs:// URI from the Object Table
      uri
    ),
    connection_id => 'projects/@@PROJECT_ID@@/locations/@@LOCATION@@/connections/sf311-conn',
    endpoint => 'gemini-2.0-flash-001'
  ).result AS summary_text
FROM todo;
