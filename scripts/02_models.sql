-- 02_models.sql
-- This script creates generative text and embeddings models
-- Env vars are substituted via Makefile + envsubst

-- Generative text model
CREATE OR REPLACE MODEL `${PROJECT_ID}.${DATASET}.gemini_text`
  REMOTE WITH CONNECTION `projects/${PROJECT_ID}/locations/${LOCATION}/connections/${CONN}`
  OPTIONS (endpoint = 'gemini-2.0-flash-001');

-- Embeddings model
CREATE OR REPLACE MODEL `${PROJECT_ID}.${DATASET}.embed_text`
  REMOTE WITH CONNECTION `projects/${PROJECT_ID}/locations/${LOCATION}/connections/${CONN}`
  OPTIONS (endpoint = 'text-embedding-005');
