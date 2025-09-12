-- 02_models.sql
-- Variables rendered via envsubst in Makefile
DECLARE project_id STRING DEFAULT '${PROJECT_ID}';
DECLARE dataset    STRING DEFAULT '${DATASET}';
DECLARE location   STRING DEFAULT '${LOCATION}';
DECLARE conn_id    STRING DEFAULT '${CONN}';

-- Generative text model
CREATE OR REPLACE MODEL `${PROJECT_ID}.${DATASET}.gemini_text`
  REMOTE WITH CONNECTION `projects/${PROJECT_ID}/locations/${LOCATION}/connections/${CONN}`
  OPTIONS (endpoint = 'gemini-2.0-flash-001');

-- Embeddings model
CREATE OR REPLACE MODEL `${PROJECT_ID}.${DATASET}.embed_text`
  REMOTE WITH CONNECTION `projects/${PROJECT_ID}/locations/${LOCATION}/connections/${CONN}`
  OPTIONS (endpoint = 'text-embedding-005');
