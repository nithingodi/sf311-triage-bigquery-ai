-- 02_models.sql
-- This script creates the two remote models needed for the project,
-- using the specific endpoints confirmed to work in this project.

CREATE OR REPLACE MODEL `@@DATASET_ID@@.gemini_text`
  REMOTE WITH CONNECTION `@@PROJECT_ID@@.@@LOCATION@@.@@BQ_CONNECTION_ID@@`
  OPTIONS (endpoint = 'gemini-2.0-flash-001');

CREATE OR REPLACE MODEL `@@DATASET_ID@@.embed_text`
  REMOTE WITH CONNECTION `@@PROJECT_ID@@.@@LOCATION@@.@@BQ_CONNECTION_ID@@`
  OPTIONS (endpoint = 'text-embedding-005');
