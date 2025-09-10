-- Project: City311 Multimodal Triage with BigQuery AI
-- Script: 02_models.sql
-- Purpose: Define BigQuery REMOTE models for Generative AI and Text Embeddings via an existing connection.
-- Inputs: Existing BigQuery connection (CLOUD_RESOURCE) that has Vertex AI access (roles/aiplatform.user).
-- Outputs: sf311.gemini_text (REMOTE), sf311.embed_text (REMOTE).
-- Idempotency: CREATE OR REPLACE MODEL (safe to re-run).
-- Parameters: Set your project/dataset/location/connection/model endpoints below.
-- Next: 02_views.sql (creates normalized and cleaned complaint text views).

-- ===========
-- PARAMETERS
-- ===========
DECLARE project_id  STRING DEFAULT 'sf311-triage-2025';
DECLARE dataset     STRING DEFAULT 'sf311';
DECLARE location    STRING DEFAULT 'US';
DECLARE gem_conn_id STRING DEFAULT 'us_gemini_conn';
DECLARE gen_endpoint STRING DEFAULT 'gemini-2.0-flash-001';
DECLARE emb_endpoint STRING DEFAULT 'text-embedding-005';

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
