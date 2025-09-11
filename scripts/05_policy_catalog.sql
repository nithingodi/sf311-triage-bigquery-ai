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
-- 05_policy_catalog.sql
CREATE OR REPLACE TABLE `sf311-triage-2025.sf311.policy_chunks` AS
SELECT * FROM UNNEST([
  STRUCT('PARK_HYDRANT','Fire Hydrants',
    'Do not stop or park within 15 feet of a fire hydrant (CA Vehicle Code §22514).',
    'https://law.justia.com/codes/california/code-veh/division-11/chapter-9/section-22514/','Illegal Parking'),
  STRUCT('PARK_DAYLIGHT','Crosswalk Daylighting (AB 413)',
    'Do not park within 20 feet of the approach side of any crosswalk—marked or unmarked—per California AB 413.',
    'https://www.sfmta.com/press-releases/press-release-sfmta-acting-transportation-director-announces-plan-fair-enforcement-californias-daylighting-law','Illegal Parking'),
  STRUCT('PARK_72HR','72-Hour Rule',
    'A vehicle may not remain parked in the same spot on a public street for more than 72 hours; may be warned, cited, or towed.',
    'https://www.sfmta.com/blog/san-francisco-parking-tips-72-hour-rule','Abandoned Vehicle'),
  STRUCT('ILLEGAL_DUMP','Illegal Dumping',
    'Illegal dumping in the public right of way is prohibited; report to 311 for cleanup and enforcement.',
    'https://www.sf.gov/report-illegal-dumping-activity','Illegal Dumping'),
  STRUCT('GRAFFITI_30D','Graffiti Removal (30 days)',
    'Private property owners must abate graffiti within 30 days of notice under Public Works Code Article 23.',
    'https://sfpublicworks.org/services/graffiti-private-property','Vandalism'),
  STRUCT('NOISE_LIMITS','Noise Limits (Police Code Art. 29)',
    'Residential interior nighttime noise limits (10pm–7am) apply; permits required for night work. See Article 29 guidelines.',
    'https://www.sf.gov/sites/default/files/2024-02/21_CACOSF_2023_Article29RegulationofNoiseGuidelines.pdf','Noise Complaint'),
  STRUCT('SIDEWALK_RESP','Sidewalk Maintenance (PW Code §706)',
    'Property owners are responsible for maintaining adjacent sidewalks and addressing hazards; failures may be deemed a public nuisance.',
    'https://sfpublicworks.org/services/permits/sidewalk-repair','Street/Sidewalk Defect'),
  STRUCT('ILLEGAL_POST','Illegal Postings',
    'Posting signs on public property is restricted; illegal postings may be removed and fined. Limited posting allowed per Article 5.6.',
    'https://sfpublicworks.org/services/posting-signs','Illegal Postings'),
  STRUCT('STREETLIGHT_RPT','Streetlight Outage',
    'Report broken or dark streetlights to 311; SFPUC maintains most streetlights in San Francisco.',
    'https://www.sf.gov/report-problem-streetlight','Streetlight Out'),
  STRUCT('BULKY_ITEMS','Bulky Item Pickup (Recology)',
    'Residents get limited no-charge bulky item pickups; schedule with Recology and place items at curb without blocking sidewalks.',
    'https://www.recology.com/recology-san-francisco/bulky-items/','Bulky Items'),
  STRUCT('HAZ_MED_WASTE','Needles/Medical Waste',
    'Do not handle sharps or medical waste; report via 311 for safe removal (typical response 12–24 hours).',
    'https://www.sf.gov/request-street-or-sidewalk-cleaning','Hazardous/Medical Waste'),
  STRUCT('HUMAN_ANIMAL_WASTE','Human/Animal Waste Cleanup',
    'Report human or animal waste via 311 for steam cleaning and disinfection (typical response 12–24 hours).',
    'https://www.sf.gov/request-street-or-sidewalk-cleaning','Human/Animal Waste'),
  STRUCT('pw_waste_001','Human/Animal Waste – Public Right of Way',
    'Public Works responds to reports of human or animal waste in the public right of way submitted via 311. Provide exact location and nearest cross street.',
    'https://sfpublicworks.org/services/garbage-and-waste','Human/Animal Waste'),
  STRUCT('pw_waste_needle_002','Needles/Medical Waste – How to Report',
    'Improperly disposed needles or medical waste… Do not handle needles yourself.',
    'https://sfpublicworks.org/services/report-problem','Human/Animal Waste')
]) AS r(policy_id, title, chunk_text, source_url, target_theme);

