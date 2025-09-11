-- Project: City311 Multimodal Triage with BigQuery AI
-- Script: 02_models.sql
-- Purpose: Define BigQuery REMOTE models for Generative AI and Text Embeddings via an existing connection.
-- Inputs: Existing BigQuery connection (CLOUD_RESOURCE) that has Vertex AI access (roles/aiplatform.user).
-- Outputs: ${DATASET}.gemini_text (REMOTE), ${DATASET}.embed_text (REMOTE).
-- Idempotency: CREATE OR REPLACE MODEL (safe to re-run).
-- Parameters: PROJECT_ID, DATASET, LOCATION, GEM_CONN_ID, GEN_ENDPOINT, EMB_ENDPOINT

-- ===========
-- PARAMETERS
-- ===========
DECLARE project_id   STRING DEFAULT "@PROJECT_ID";
DECLARE dataset      STRING DEFAULT "@DATASET";
DECLARE location     STRING DEFAULT "@LOCATION";
DECLARE gem_conn_id  STRING DEFAULT "@GEM_CONN_ID";
DECLARE gen_endpoint STRING DEFAULT "@GEN_ENDPOINT";
DECLARE emb_endpoint STRING DEFAULT "@EMB_ENDPOINT";

-- ================================
-- Generative REMOTE model (Gemini)
-- ================================
EXECUTE IMMEDIATE FORMAT("""
  CREATE OR REPLACE MODEL `%s.%s.gemini_text`
  REMOTE WITH CONNECTION `projects/%s/locations/%s/connections/%s`
  OPTIONS (endpoint = '%s')
""", project_id, dataset, project_id, location, gem_conn_id, gen_endpoint);

-- ===================================
-- Text Embedding REMOTE model (005)
-- ===================================
EXECUTE IMMEDIATE FORMAT("""
  CREATE OR REPLACE MODEL `%s.%s.embed_text`
  REMOTE WITH CONNECTION `projects/%s/locations/%s/connections/%s`
  OPTIONS (endpoint = '%s')
""", project_id, dataset, project_id, location, gem_conn_id, emb_endpoint);
