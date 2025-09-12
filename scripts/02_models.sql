-- 02_models.sql
DECLARE project_id STRING DEFAULT "${PROJECT_ID}";
DECLARE dataset    STRING DEFAULT "${DATASET}";
DECLARE location   STRING DEFAULT "${LOCATION}";
DECLARE conn_id    STRING DEFAULT "${CONN}";

-- Generative text model (must include dataset)
EXECUTE IMMEDIATE FORMAT("""
CREATE OR REPLACE MODEL `%s.%s.gemini_text`
REMOTE WITH CONNECTION `projects/%s/locations/%s/connections/%s`
OPTIONS (endpoint = 'gemini-2.0-flash-001');
""", project_id, dataset, project_id, location, conn_id);

-- Embeddings model
EXECUTE IMMEDIATE FORMAT("""
CREATE OR REPLACE MODEL `%s.%s.embed_text`
REMOTE WITH CONNECTION `projects/%s/locations/%s/connections/%s`
OPTIONS (endpoint = 'text-embedding-005');
""", project_id, dataset, project_id, location, conn_id);
