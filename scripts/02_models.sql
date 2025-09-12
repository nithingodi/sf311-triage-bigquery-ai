-- 02_models.sql
-- Create generative text and embedding models (remote)

DECLARE project_id STRING DEFAULT "${PROJECT_ID}";
DECLARE dataset    STRING DEFAULT "${DATASET}";
DECLARE location   STRING DEFAULT "${LOCATION}";
DECLARE conn_id    STRING DEFAULT "${CONN}";

-- Generative text model
CREATE OR REPLACE MODEL `${project_id}.${dataset}.gemini_text`
REMOTE WITH CONNECTION `projects/${project_id}/locations/${location}/connections/${conn_id}`
OPTIONS (endpoint = 'gemini-2.0-flash-001');

-- Embeddings model
CREATE OR REPLACE MODEL `${project_id}.${dataset}.embed_text`
REMOTE WITH CONNECTION `projects/${project_id}/locations/${location}/connections/${conn_id}`
OPTIONS (endpoint = 'text-embedding-005');
