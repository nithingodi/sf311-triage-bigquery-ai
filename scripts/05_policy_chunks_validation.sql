-- 4) Create validation view to check if all target_theme values exist in label_taxonomy
CREATE OR REPLACE VIEW `@@PROJECT_ID@@.@@DATASET_ID@@.policy_chunks_validation` AS
SELECT
  pc.policy_id,
  pc.title,
  pc.target_theme,
  CASE 
    WHEN lt.label_value IS NULL THEN 'missing_in_taxonomy'
    ELSE 'ok'
  END AS theme_status
FROM `@@PROJECT_ID@@.@@DATASET_ID@@.policy_chunks` pc
LEFT JOIN `@@PROJECT_ID@@.@@DATASET_ID@@.label_taxonomy` lt
  ON LOWER(pc.target_theme) = LOWER(lt.label_value) AND lt.label_type = 'theme';
