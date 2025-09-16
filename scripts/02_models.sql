CREATE OR REPLACE MODEL `@@PROJECT_ID@@.@@DATASET_ID@@.gemini_text`
REMOTE WITH CONNECTION `projects/@@PROJECT_ID@@/locations/@@LOCATION@@/connections/sf311-conn`
OPTIONS (endpoint = 'gemini-2.0-flash-001');

CREATE OR REPLACE MODEL `@@PROJECT_ID@@.@@DATASET_ID@@.embed_text`
REMOTE WITH CONNECTION `projects/@@PROJECT_ID@@/locations/@@LOCATION@@/connections/sf311-conn`
OPTIONS (endpoint = 'text-embedding-004');
