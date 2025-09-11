-- Project: City311 Multimodal Triage with BigQuery AI
-- Script: 05_label_taxonomy.sql
-- Purpose: Define the canonical label taxonomy used for triage prompts and evaluation.
-- Inputs:  (none)
-- Outputs: label_taxonomy (TABLE)
-- Idempotency: CREATE OR REPLACE (safe).

-- ===========
-- PARAMETERS
-- ===========
DECLARE project_id STRING DEFAULT "@PROJECT_ID";
DECLARE dataset    STRING DEFAULT "@DATASET";

-- ==========================
-- Canonical label taxonomy
-- ==========================
EXECUTE IMMEDIATE FORMAT("""
CREATE OR REPLACE TABLE `%s.%s.label_taxonomy` AS
SELECT * FROM UNNEST([
  'Illegal Parking','Abandoned Vehicle','Garbage Overflow','Illegal Dumping','Garbage Collection',
  'Debris Removal','Mold/Mildew','Building Maintenance','Tree Maintenance','Vandalism',
  'Noise Complaint','Flooding','Utility Complaint','Employee Conduct',
  'Bulky Items','Encampment','Human/Animal Waste','Street/Sidewalk Defect',
  'Streetlight Out','Hazardous/Medical Waste','Illegal Postings'
]) AS theme;
""", project_id, dataset);
