-- 05_policy_catalog_upsert.sql
DECLARE project_id STRING DEFAULT '${PROJECT_ID}';
DECLARE dataset    STRING DEFAULT '${DATASET}';

CREATE TABLE IF NOT EXISTS `${PROJECT_ID}.${DATASET}.policy_catalog` (
  policy_title   STRING,
  source_url     STRING,
  policy_snippet STRING,
  theme          STRING
);

-- Keep your existing UNNEST rows; the key fix is eliminating any '%s'.
MERGE `${PROJECT_ID}.${DATASET}.policy_catalog` T
USING (
  SELECT * FROM UNNEST([
    -- Example row; replace with your curated entries.
    STRUCT('Illegal Parking — Tow Zones' AS policy_title,
           'https://example'           AS source_url,
           'Tow if posted tow-away'    AS policy_snippet,
           'Illegal Parking'           AS theme)
  ])
) S
ON T.policy_title = S.policy_title
WHEN MATCHED THEN UPDATE SET
  source_url     = S.source_url,
  policy_snippet = S.policy_snippet,
  theme          = S.theme
WHEN NOT MATCHED THEN
  INSERT (policy_title, source_url, policy_snippet, theme)
  VALUES (S.policy_title, S.source_url, S.policy_snippet, S.theme);
