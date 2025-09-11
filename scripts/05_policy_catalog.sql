-- Project: City311 Multimodal Triage with BigQuery AI
-- Script: 05_policy_catalog.sql
-- Purpose: Seed a lightweight policy/pattern catalog used for vector matching & action alignment.
-- Inputs:  (optional) sf311.label_taxonomy for validation (created in 05_label_taxonomy.sql)
-- Outputs: TABLE sf311.policy_chunks
--          VIEW  sf311.policy_chunks_validation  (flags themes not in taxonomy)
-- Idempotency: CREATE OR REPLACE (safe).
-- Next: 06_matching.sql (embed policies & complaints, vector search for best policy)

-- ===========
-- PARAMETERS
-- ===========
DECLARE project_id STRING DEFAULT 'sf311-triage-2025';
DECLARE dataset    STRING DEFAULT 'sf311';

-- =========================
-- Seed policy chunks table
-- =========================
-- 05_policy_catalog.sql (named fields; idempotent)

CREATE OR REPLACE TABLE `sf311-triage-2025.sf311.policy_chunks` AS
SELECT policy_id, title, chunk_text, source_url, target_theme
FROM UNNEST([
  STRUCT('PARK_HYDRANT'  AS policy_id, 'Fire Hydrants' AS title,
        'Do not stop or park within 15 feet of a fire hydrant (CA Vehicle Code §22514).' AS chunk_text,
        'https://law.justia.com/codes/california/code-veh/division-11/chapter-9/section-22514/' AS source_url,
        'Illegal Parking' AS target_theme),

  STRUCT('PARK_DAYLIGHT' AS policy_id, 'Crosswalk Daylighting (AB 413)' AS title,
        'Do not park within 20 feet of the approach side of any crosswalk—marked or unmarked—per California AB 413.' AS chunk_text,
        'https://www.sfmta.com/press-releases/press-release-sfmta-acting-transportation-director-announces-plan-fair-enforcement-californias-daylighting-law' AS source_url,
        'Illegal Parking' AS target_theme),

  STRUCT('PARK_72HR' AS policy_id, '72-Hour Rule' AS title,
        'A vehicle may not remain parked in the same spot on a public street for more than 72 hours; may be warned, cited, or towed.' AS chunk_text,
        'https://www.sfmta.com/blog/san-francisco-parking-tips-72-hour-rule' AS source_url,
        'Abandoned Vehicle' AS target_theme),

  STRUCT('ILLEGAL_DUMP' AS policy_id, 'Illegal Dumping' AS title,
        'Illegal dumping in the public right of way is prohibited; report to 311 for cleanup and enforcement.' AS chunk_text,
        'https://www.sf.gov/report-illegal-dumping-activity' AS source_url,
        'Illegal Dumping' AS target_theme),

  STRUCT('GRAFFITI_30D' AS policy_id, 'Graffiti Removal (30 days)' AS title,
        'Private property owners must abate graffiti within 30 days of notice under Public Works Code Article 23.' AS chunk_text,
        'https://sfpublicworks.org/services/graffiti-private-property' AS source_url,
        'Vandalism' AS target_theme),

  STRUCT('NOISE_LIMITS' AS policy_id, 'Noise Limits (Police Code Art. 29)' AS title,
        'Residential interior nighttime noise limits (10pm–7am) apply; permits required for night work. See Article 29 guidelines.' AS chunk_text,
        'https://www.sf.gov/sites/default/files/2024-02/21_CACOSF_2023_Article29RegulationofNoiseGuidelines.pdf' AS source_url,
        'Noise Complaint' AS target_theme),

  STRUCT('SIDEWALK_RESP' AS policy_id, 'Sidewalk Maintenance (PW Code §706)' AS title,
        'Property owners are responsible for maintaining adjacent sidewalks and addressing hazards; failures may be deemed a public nuisance.' AS chunk_text,
        'https://sfpublicworks.org/services/permits/sidewalk-repair' AS source_url,
        'Street/Sidewalk Defect' AS target_theme),

  STRUCT('ILLEGAL_POST' AS policy_id, 'Illegal Postings' AS title,
        'Posting signs on public property is restricted; illegal postings may be removed and fined. Limited posting allowed per Article 5.6.' AS chunk_text,
        'https://sfpublicworks.org/services/posting-signs' AS source_url,
        'Illegal Postings' AS target_theme),

  STRUCT('STREETLIGHT_RPT' AS policy_id, 'Streetlight Outage' AS title,
        'Report broken or dark streetlights to 311; SFPUC maintains most streetlights in San Francisco.' AS chunk_text,
        'https://www.sf.gov/report-problem-streetlight' AS source_url,
        'Streetlight Out' AS target_theme),

  STRUCT('BULKY_ITEMS' AS policy_id, 'Bulky Item Pickup (Recology)' AS title,
        'Residents get limited no-charge bulky item pickups; schedule with Recology and place items at curb without blocking sidewalks.' AS chunk_text,
        'https://www.recology.com/recology-san-francisco/bulky-items/' AS source_url,
        'Bulky Items' AS target_theme),

  STRUCT('HAZ_MED_WASTE' AS policy_id, 'Needles/Medical Waste' AS title,
        'Do not handle sharps or medical waste; report via 311 for safe removal (typical response 12–24 hours).' AS chunk_text,
        'https://www.sf.gov/request-street-or-sidewalk-cleaning' AS source_url,
        'Hazardous/Medical Waste' AS target_theme),

  STRUCT('HUMAN_ANIMAL_WASTE' AS policy_id, 'Human/Animal Waste Cleanup' AS title,
        'Report human or animal waste via 311 for steam cleaning and disinfection (typical response 12–24 hours).' AS chunk_text,
        'https://www.sf.gov/request-street-or-sidewalk-cleaning' AS source_url,
        'Human/Animal Waste' AS target_theme),

  -- Extra chunks you added later:
  STRUCT('pw_waste_001' AS policy_id, 'Human/Animal Waste – Public Right of Way' AS title,
        'Public Works responds to reports of human or animal waste in the public right of way submitted via 311. Provide exact location and nearest cross street.' AS chunk_text,
        'https://sfpublicworks.org/services/garbage-and-waste' AS source_url,
        'Human/Animal Waste' AS target_theme),

  STRUCT('pw_waste_needle_002' AS policy_id, 'Needles/Medical Waste – How to Report' AS title,
        'Improperly disposed needles or medical waste should be reported through 311; do not handle needles yourself.' AS chunk_text,
        'https://sfpublicworks.org/services/report-problem' AS source_url,
        'Human/Animal Waste' AS target_theme)
]) AS t;

-- Keep validation as a VIEW to avoid table/view collisions
CREATE OR REPLACE VIEW `sf311-triage-2025.sf311.policy_chunks_validation` AS
SELECT
  pc.policy_id, pc.title, pc.target_theme,
  CASE WHEN lt.theme IS NULL THEN 'missing_in_taxonomy' ELSE 'ok' END AS theme_status
FROM `sf311-triage-2025.sf311.policy_chunks` pc
LEFT JOIN `sf311-triage-2025.sf311.label_taxonomy` lt
  ON LOWER(pc.target_theme) = LOWER(lt.theme);
SQL

