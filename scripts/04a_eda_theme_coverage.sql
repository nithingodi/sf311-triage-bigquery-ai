-- Project: City311 Multimodal Triage with BigQuery AI
-- Script: 04a_eda_theme_coverage.sql
-- Purpose: EDA to estimate coverage using an expanded taxonomy (request_type + text heuristics).
-- Inputs:  sf311.cases_text_quality
-- Outputs: Resultset only (no tables). Use for writeup charts.
-- Idempotency: N/A (read-only).
-- Notes: This is analysis-only; safe to omit in automated runs.

DECLARE project_id STRING DEFAULT 'sf311-triage-2025';
DECLARE dataset    STRING DEFAULT 'sf311';

WITH base AS (
  SELECT
    service_request_id,
    LOWER(text_norm)   AS t,
    LOWER(request_type) AS rt,
    request_type,
    text_norm
  FROM `${project_id}.${dataset}.cases_text_quality`
),
mapped AS (
  SELECT
    service_request_id,
    request_type,
    CASE
      WHEN rt LIKE 'bulky items%%'                                      THEN 'Bulky Items'
      WHEN rt LIKE 'encampment reports%%'                               THEN 'Encampment'
      WHEN rt LIKE 'human or animal waste%%'                             THEN 'Human/Animal Waste'
      WHEN rt LIKE 'streetlight - light_burnt_out%%'                     THEN 'Streetlight Out'
      WHEN rt LIKE 'pavement_defect%%' OR rt LIKE 'sidewalk_defect%%'    THEN 'Street/Sidewalk Defect'
      WHEN rt LIKE 'illegal postings%%'                                  THEN 'Illegal Postings'
      WHEN rt LIKE 'medical waste%%' OR rt LIKE 'hazardous materials%%'  THEN 'Hazardous/Medical Waste'
      WHEN rt LIKE 'garbage_and_debris%%'                                THEN 'Debris Removal'
      WHEN rt LIKE 'graffiti on %%'                                      THEN 'Vandalism'
      WHEN rt LIKE 'parking_on_sidewalk%%' 
        OR rt LIKE 'blocking_driveway_cite_only%%' 
        OR rt LIKE 'blocking_driveway_cite_tow%%' 
        OR rt LIKE 'other_illegal_parking%%'                             THEN 'Illegal Parking'
      WHEN rt LIKE 'abandoned vehicle%%'                                 THEN 'Abandoned Vehicle'
      WHEN REGEXP_CONTAINS(t, r'\billegal dump|dump(ing)?\b|mattress|furniture')                     THEN 'Illegal Dumping'
      WHEN REGEXP_CONTAINS(t, r'\b(overflow|trash|garbage|bin|cart|litter)\b')                       THEN 'Garbage Overflow'
      WHEN REGEXP_CONTAINS(t, r'\b(missed|skipped|miss)\b.*\b(pick ?up|collection)\b')
        OR REGEXP_CONTAINS(t, r'\bgarbage collection|trash collection|recycling collection\b')       THEN 'Garbage Collection'
      WHEN REGEXP_CONTAINS(t, r'\babandon(ed|ment)?\b|\b72[- ]?hour\b|\bstored vehicle\b')           THEN 'Abandoned Vehicle'
      WHEN REGEXP_CONTAINS(t, r'\b(tow|towing|blocked|driveway|hydrant|crosswalk|double ?park|parking|ticket)\b') THEN 'Illegal Parking'
      WHEN REGEXP_CONTAINS(t, r'\bmold|mildew\b')                                                    THEN 'Mold/Mildew'
      WHEN REGEXP_CONTAINS(t, r'\b(building|maintenance|repair|code|violation|structure)\b')         THEN 'Building Maintenance'
      WHEN REGEXP_CONTAINS(t, r'\btree|branch|prune|fallen|arborist\b')                              THEN 'Tree Maintenance'
      WHEN REGEXP_CONTAINS(t, r'\bgraffiti|vandal(ism|ize|ized)?\b')                                 THEN 'Vandalism'
      WHEN REGEXP_CONTAINS(t, r'\bnoise|loud|music|party|amplified\b')                               THEN 'Noise Complaint'
      WHEN REGEXP_CONTAINS(t, r'\bflood(ing)?\b|\bstanding water\b|\b(storm)? ?drain\b|\bsewer\b')  THEN 'Flooding'
      WHEN REGEXP_CONTAINS(t, r'\b(power|electric|gas|water (out|leak)|utility)\b')                  THEN 'Utility Complaint'
      WHEN REGEXP_CONTAINS(t, r'\b(employee|conduct|rude|discourteous|staff)\b')                     THEN 'Employee Conduct'
      ELSE 'Other'
    END AS theme_v3,
    text_norm
  FROM base
),
theme_agg AS (
  SELECT theme_v3 AS name, COUNT(*) AS ct, ROUND(100*COUNT(*)/SUM(COUNT(*)) OVER (),2) AS pct
  FROM mapped GROUP BY name
),
unmatched_top AS (
  SELECT request_type AS name, COUNT(*) AS ct, ROUND(100*COUNT(*)/SUM(COUNT(*)) OVER (),2) AS pct
  FROM mapped WHERE theme_v3='Other' GROUP BY request_type ORDER BY ct DESC LIMIT 20
)
SELECT 'theme' AS kind, name, ct, pct FROM theme_agg
UNION ALL
SELECT 'unmatched_request_type' AS kind, name, ct, pct FROM unmatched_top
ORDER BY kind, ct DESC;
