-- Project: City311 Multimodal Triage with BigQuery AI
-- Script: 05_policy_catalog_upsert.sql
-- Purpose: Upsert (MERGE) additional policy chunks into sf311.policy_chunks
-- Inputs:  (VALUES clause below)
-- Outputs: Updated sf311.policy_chunks without duplicates
-- Idempotency: MERGE (safe to re-run)

DECLARE project_id STRING DEFAULT 'sf311-triage-2025';
DECLARE dataset    STRING DEFAULT 'sf311';

-- 05_policy_catalog_upsert.sql (plain)
MERGE `sf311-triage-2025.sf311.policy_chunks` T
USING (
  SELECT * FROM UNNEST([
    STRUCT('recology_bulky_001','Bulky Item Recycling – Residential Allotment',
      'San Francisco residential customers receive a limited number of no-charge curbside bulky item collections. Place items by 6am and label “Recology.”',
      'https://www.recology.com/recology-san-francisco/bulky-items/','Bulky Items'),
    STRUCT('recology_bulky_002','Bulky Item Recycling – Scheduling & Day-of Rules',
      'After scheduling, set items curbside by 6am and attach a sign marked “Recology.” Program rules and eligibility apply.',
      'https://www.recology.com/faq/sf-bulky-item-collection/','Bulky Items'),
    STRUCT('sf_illegal_dumping_001','Illegal Dumping – 311 Routing',
      '311 routes illegal dumping to Public Works or Recology depending on material and location.',
      'https://www.sf.gov/report-illegal-dumping-activity','Illegal Dumping'),
    STRUCT('sf_illegal_dumping_002','Illegal Dumping – Assignment Overview',
      'City process describes assignment/completion steps across agencies.',
      'https://media.api.sf.gov/documents/Illegal_Dumping_Final_Report.pdf','Illegal Dumping'),
    STRUCT('pw_graffiti_public_001','Graffiti on Public Property – Response',
      'Public Works paints out graffiti on public property; report via 311.',
      'https://sfpublicworks.org/services/graffiti','Vandalism'),
    STRUCT('pw_graffiti_private_002','Graffiti on Private Property – 30-Day Abatement',
      'Owners must remove graffiti within 30 days of notice per Article 23.',
      'https://sfpublicworks.org/services/graffiti-private-property','Vandalism'),
    STRUCT('sf_sidewalk_001','Sidewalk/Curb Problems – Reporting & Responsibility',
      'Report cracked, lifted, or defective sidewalks/curbs via 311.',
      'https://www.sf.gov/report-curb-and-sidewalk-problems','Street/Sidewalk Defect'),
    STRUCT('pw_sidewalk_permit_002','Sidewalk Repair – Permit & Contractor Requirements',
      'Use licensed A or C-8 contractor and secure required permits/bonds.',
      'https://sfpublicworks.org/services/permits/sidewalk-repair','Street/Sidewalk Defect'),
    STRUCT('sfmta_abandoned_001','Abandoned Vehicle – 72-Hour Rule',
      'Vehicles left >72 hours may be cited or towed; report suspected abandoned vehicles via 311.',
      'https://www.sfmta.com/getting-around/drive-park/towed-vehicles','Abandoned Vehicle'),
    STRUCT('sf_streetlight_001','Streetlight Problems – What to Report',
      'Report streetlights that are out, flickering, dim, always on, or with exposed wires.',
      'https://www.sf.gov/report-problem-streetlight','Streetlight Out'),
    STRUCT('hsoc_001','Encampments – Coordinated Response (HSOC)',
      'HSOC coordinates phased approach; 311 routes non-encampment issues to Public Works.',
      'https://sfcontroller.org/sites/default/files/Documents/Auditing/Review%20of%20the%20Healthy%20Streets%20Operations%20Center.pdf','Encampment')
  ])
) S
ON T.policy_id = S.policy_id
WHEN NOT MATCHED THEN
  INSERT (policy_id, title, chunk_text, source_url, target_theme)
  VALUES (S.policy_id, S.title, S.chunk_text, S.source_url, S.target_theme);

-- Validate taxonomy alignment as a VIEW (avoid table/view clashes)
CREATE OR REPLACE VIEW `sf311-triage-2025.sf311.policy_chunks_validation` AS
SELECT
  pc.policy_id, pc.title, pc.target_theme,
  CASE WHEN lt.theme IS NULL THEN 'missing_in_taxonomy' ELSE 'ok' END AS theme_status
FROM `sf311-triage-2025.sf311.policy_chunks` pc
LEFT JOIN `sf311-triage-2025.sf311.label_taxonomy` lt
  ON LOWER(pc.target_theme) = LOWER(lt.theme);

