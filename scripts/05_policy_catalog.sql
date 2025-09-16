-- Seeds a lightweight policy/pattern catalog.
CREATE OR REPLACE TABLE `@@PROJECT_ID@@.@@DATASET_ID@@.policy_chunks` (
  policy_id STRING,
  title STRING,
  chunk_text STRING,
  source_url STRING,
  target_theme STRING
);

INSERT INTO `@@PROJECT_ID@@.@@DATASET_ID@@.policy_chunks` (policy_id, title, chunk_text, source_url, target_theme)
VALUES
  ('PARK_HYDRANT','Fire Hydrants', 'Do not stop or park within 15 feet of a fire hydrant (California Vehicle Code Section 22514).', 'https://law.justia.com/codes/california/code-veh/division-11/chapter-9/section-22514/','Illegal Parking'),
  ('PARK_DAYLIGHT','Crosswalk Daylighting (AB 413)', 'Do not park within 20 feet of the approach side of any crosswalk, marked or unmarked, per California AB 413.', 'https://www.sfmta.com/press-releases/press-release-sfmta-acting-transportation-director-announces-plan-fair-enforcement-californias-daylighting-law', 'Illegal Parking'),
  ('PARK_72HR','72-Hour Rule', 'A vehicle may not remain parked in the same spot on a public street for more than 72 hours; may be warned, cited, or towed.', 'https://www.sfmta.com/blog/san-francisco-parking-tips-72-hour-rule','Abandoned Vehicle'),
  ('ILLEGAL_DUMP','Illegal Dumping', 'Illegal dumping in the public right of way is prohibited; report to 311 for cleanup and enforcement.', 'https://www.sf.gov/report-illegal-dumping-activity','Illegal Dumping'),
  ('GRAFFITI_30D','Graffiti Removal (30 days)', 'Private property owners must abate graffiti within 30 days of notice under Public Works Code Article 23.', 'https://sfpublicworks.org/services/graffiti-private-property','Vandalism'),
  ('NOISE_LIMITS','Noise Limits (Police Code Article 29)', 'Residential interior nighttime noise limits (10pm–7am) apply; permits required for night work.', 'https://www.sf.gov/sites/default/files/2024-02/21_CACOSF_2023_Article29RegulationofNoiseGuidelines.pdf','Noise Complaint'),
  ('SIDEWALK_RESP','Sidewalk Maintenance (Public Works Code 706)', 'Property owners are responsible for maintaining adjacent sidewalks and addressing hazards; failures may be deemed a public nuisance.', 'https://sfpublicworks.org/services/permits/sidewalk-repair','Street/Sidewalk Defect'),
  ('ILLEGAL_POST','Illegal Postings', 'Posting signs on public property is restricted; illegal postings may be removed and fined. Limited posting allowed per Article 5.6.', 'https://sfpublicworks.org/services/posting-signs','Illegal Postings'),
  ('STREETLIGHT_RPT','Streetlight Outage', 'Report broken or dark streetlights to 311; SFPUC maintains most streetlights in San Francisco.', 'https://www.sf.gov/report-problem-streetlight','Streetlight Out'),
  ('BULKY_ITEMS','Bulky Item Pickup (Recology)', 'Residents get limited no-charge bulky item pickups; schedule with Recology and place items at curb without blocking sidewalks.', 'https://www.recology.com/recology-san-francisco/bulky-items/','Bulky Items'),
  ('HAZ_MED_WASTE','Needles/Medical Waste', 'Do not handle sharps or medical waste; report via 311 for safe removal (typical response 12–24 hours).', 'https://www.sf.gov/request-street-or-sidewalk-cleaning','Hazardous/Medical Waste'),
  ('HUMAN_ANIMAL_WASTE','Human/Animal Waste Cleanup', 'Report human or animal waste via 311 for steam cleaning and disinfection (typical response 12–24 hours).', 'https://www.sf.gov/request-street-or-sidewalk-cleaning','Human/Animal Waste'),
  ('pw_waste_001','Human/Animal Waste - Public Right of Way', 'Public Works responds to reports of human or animal waste in the public right of way submitted via 311. Provide exact location and nearest cross street.', 'https://sfpublicworks.org/services/garbage-and-waste','Human/Animal Waste'),
  ('pw_waste_needle_002','Needles/Medical Waste - How to Report', 'Improperly disposed needles or medical waste should be reported through 311; do not handle needles yourself.', 'https://sfpublicworks.org/services/report-problem','Human/Animal Waste');


-- Creates the policy_catalog table with a single batch-run of ML.GENERATE_EMBEDDING.
CREATE OR REPLACE TABLE `@@PROJECT_ID@@.@@DATASET_ID@@.policy_catalog` AS
SELECT
  policy_id,
  title,
  chunk_text,
  source_url,
  target_theme,
  (SELECT embedding FROM ML.GENERATE_EMBEDDING(
    MODEL `@@PROJECT_ID@@.@@DATASET_ID@@.embed_text`,
    (SELECT AS STRUCT chunk_text AS content)
  )) AS embedding
FROM `@@PROJECT_ID@@.@@DATASET_ID@@.policy_chunks`;

-- Creates a validation view to check if themes in the policy catalog exist in the label taxonomy.
CREATE OR REPLACE VIEW `@@PROJECT_ID@@.@@DATASET_ID@@.policy_chunks_validation` AS
SELECT
  pc.policy_id,
  pc.title,
  pc.target_theme,
  CASE
    WHEN lt.label_value IS NULL THEN 'missing_in_taxonomy'
    ELSE 'ok'
  END AS theme_status
FROM `@@PROJECT_ID@@.@@DATASET_ID@@.policy_chunks` AS pc
LEFT JOIN `@@PROJECT_ID@@.@@DATASET_ID@@.label_taxonomy` AS lt
  ON LOWER(pc.target_theme) = LOWER(lt.label_value) AND lt.label_type = 'theme';
