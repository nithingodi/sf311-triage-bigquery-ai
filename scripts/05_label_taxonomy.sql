-- Project: City311 Multimodal Triage with BigQuery AI
-- Script: 05_label_taxonomy.sql
-- Purpose: Define the canonical label taxonomy used for triage prompts and evaluation.
-- Inputs:  (none)
-- Outputs: TABLE sf311.label_taxonomy (theme STRING)
-- Idempotency: CREATE OR REPLACE (safe).

DECLARE project_id STRING DEFAULT 'sf311-triage-2025';
DECLARE dataset    STRING DEFAULT 'sf311';

-- 05_label_taxonomy.sql
CREATE OR REPLACE TABLE `sf311-triage-2025.sf311.label_taxonomy` AS
SELECT * FROM UNNEST([
  'Illegal Parking','Abandoned Vehicle','Garbage Overflow','Illegal Dumping','Garbage Collection',
  'Debris Removal','Mold/Mildew','Building Maintenance','Tree Maintenance','Vandalism',
  'Noise Complaint','Flooding','Utility Complaint','Employee Conduct',
  'Bulky Items','Encampment','Human/Animal Waste','Street/Sidewalk Defect',
  'Streetlight Out','Hazardous/Medical Waste','Illegal Postings'
]) AS theme;
