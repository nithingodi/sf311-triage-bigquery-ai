-- 02_models.sql
-- This script creates the two remote models needed for the project:
-- 1. A generative model based on Gemini Pro.
-- 2. An embedding model to create vector representations of text.

CREATE OR REPLACE MODEL `@@DATASET_ID@@.gemini_pro_model`
  REMOTE WITH CONNECTION `@@PROJECT_ID@@.@@LOCATION@@.@@BQ_CONNECTION_ID@@`
  OPTIONS (endpoint = 'gemini-pro');

CREATE OR REPLACE MODEL `@@DATASET_ID@@.embedding_model`
  REMOTE WITH CONNECTION `@@PROJECT_ID@@.@@LOCATION@@.@@BQ_CONNECTION_ID@@`
  OPTIONS (endpoint = 'text-embedding-004');
