-- Creates a table defining the valid labels for triage results.
CREATE OR REPLACE TABLE `@@PROJECT_ID@@.@@DATASET_ID@@.label_taxonomy` (
  label_type STRING,
  label_value STRING
);

INSERT INTO `@@PROJECT_ID@@.@@DATASET_ID@@.label_taxonomy` (label_type, label_value)
VALUES
  -- Severity Labels
  ('severity', 'Low'),
  ('severity', 'Medium'),
  ('severity', 'High'),
  ('severity', 'Critical'),

  -- Action Labels
  ('action', 'Dispatch'),
  ('action', 'Maintenance'),
  ('action', 'Information'),
  ('action', 'Policy'),

  -- Theme Labels (NEW)
  ('theme', 'Illegal Parking'),
  ('theme', 'Abandoned Vehicle'),
  ('theme', 'Illegal Dumping'),
  ('theme', 'Vandalism'),
  ('theme', 'Noise Complaint'),
  ('theme', 'Street/Sidewalk Defect'),
  ('theme', 'Illegal Postings'),
  ('theme', 'Streetlight Out'),
  ('theme', 'Bulky Items'),
  ('theme', 'Hazardous/Medical Waste'),
  ('theme', 'Human/Animal Waste');
