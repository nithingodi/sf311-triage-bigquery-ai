CREATE OR REPLACE MODEL `@@PROJECT_ID@@.@@DATASET_ID@@.gemini_text`
REMOTE WITH CONNECTION `projects/@@PROJECT_ID@@/locations/@@LOCATION@@/connections/sf311-conn`
OPTIONS (endpoint = 'gemini-1.5-flash');

CREATE OR REPLACE MODEL `@@PROJECT_ID@@.@@DATASET_ID@@.embed_text`
REMOTE WITH CONNECTION `projects/@@PROJECT_ID@@/locations/@@LOCATION@@/connections/sf311-conn`
OPTIONS (endpoint = 'text-embedding-004');
