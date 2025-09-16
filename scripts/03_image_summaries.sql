-- Creates or replaces a table of image summaries using the Gemini model
-- for cases that have media but poor quality text.
CREATE OR REPLACE TABLE `@@PROJECT_ID@@.@@DATASET_ID@@.image_summaries` AS
SELECT
  s.service_request_id,
  ML.GENERATE_TEXT(
    MODEL `@@PROJECT_ID@@.@@DATASET_ID@@.gemini_text`,
    -- input struct for the model
    (SELECT AS STRUCT
      CONCAT(
        'Summarize this SF311 complaint photo in one concise sentence (<= 30 words). The complaint is about: ',
        s.request_type,
        '. Return only the sentence.'
      ) AS prompt,
      [s.media_url] AS uris
    ),
    -- options as a struct (explicit & safer than raw JSON)
    (SELECT AS STRUCT 0.1 AS temperature, 256 AS max_output_tokens)
  ) AS summary_result
FROM `@@PROJECT_ID@@.@@DATASET_ID@@.cases_text_quality` AS s
WHERE s.has_media AND s.is_bad_text;
