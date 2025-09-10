-- Project: City311 Multimodal Triage with BigQuery AI
-- Script: 05_policy_catalog_upsert.sql
-- Purpose: Upsert (MERGE) additional policy chunks into sf311.policy_chunks
-- Inputs:  (VALUES clause below)
-- Outputs: Updated sf311.policy_chunks without duplicates
-- Idempotency: MERGE (safe to re-run)

DECLARE project_id STRING DEFAULT 'sf311-triage-2025';
DECLARE dataset    STRING DEFAULT 'sf311';

-- Staging rows to upsert (all blocks you pasted are included)
CREATE TEMP TABLE policy_upserts AS
SELECT * FROM UNNEST([
  STRUCT('pw_waste_001'         AS policy_id, 'Human/Animal Waste – Public Right of Way'                   AS title,
        'Public Works responds to reports of human or animal waste in the public right of way submitted via 311. The service removes waste that is PW’s responsibility, typically during standard weekday windows; complex cases may require an action plan. Provide exact location and nearest cross street when reporting.' AS chunk_text,
        'Human/Animal Waste'     AS target_theme,
        'https://sfpublicworks.org/services/garbage-and-waste' AS source_url),

  STRUCT('pw_waste_needle_002'  AS policy_id, 'Needles/Medical Waste – How to Report'                      AS title,
        'Improperly disposed needles or medical waste in streets or on sidewalks should be reported through 311 so an appropriate crew can be dispatched. Include a precise location and any safety concerns. Do not handle needles yourself.' AS chunk_text,
        'Human/Animal Waste'     AS target_theme,
        'https://sfpublicworks.org/services/report-problem' AS source_url),

  STRUCT('recology_bulky_001'   AS policy_id, 'Bulky Item Recycling – Residential Allotment'               AS title,
        'San Francisco residential customers receive a limited number of no-charge curbside bulky item collections. Schedule with Recology; place items at the curb by 6am on collection day and label “Recology.” Extra collections may incur fees.' AS chunk_text,
        'Bulky Items'            AS target_theme,
        'https://www.recology.com/recology-san-francisco/bulky-items/' AS source_url),

  STRUCT('recology_bulky_002'   AS policy_id, 'Bulky Item Recycling – Scheduling & Day-of Rules'           AS title,
        'After scheduling a bulky pickup, set items curbside by 6am on the appointment day and attach a sign marked “Recology.” Requests are confirmed after submitting scheduling details; program rules and eligibility apply.' AS chunk_text,
        'Bulky Items'            AS target_theme,
        'https://www.recology.com/faq/sf-bulky-item-collection/' AS source_url),

  STRUCT('sf_illegal_dumping_001' AS policy_id, 'Illegal Dumping – 311 Routing'                            AS title,
        'Illegal dumping reports are submitted via 311. Based on material and location, the ticket is routed to Public Works or Recology for cleanup. Witness info may be requested; follow-up cleaning requests may be created as needed.' AS chunk_text,
        'Illegal Dumping'        AS target_theme,
        'https://www.sf.gov/report-illegal-dumping-activity' AS source_url),

  STRUCT('sf_illegal_dumping_002' AS policy_id, 'Illegal Dumping – Assignment Overview'                    AS title,
        'City process routes illegal dumping to Public Works or Recology depending on item type and circumstances. Process documents describe assignment and completion steps across agencies.' AS chunk_text,
        'Illegal Dumping'        AS target_theme,
        'https://media.api.sf.gov/documents/Illegal_Dumping_Final_Report.pdf' AS source_url),

  STRUCT('pw_graffiti_public_001' AS policy_id, 'Graffiti on Public Property – Response'                   AS title,
        'Public Works paints out graffiti on public property and coordinates with other agencies for their assets. Report via 311 (web/app/phone). For graffiti in progress, call 911.' AS chunk_text,
        'Vandalism'              AS target_theme,
        'https://sfpublicworks.org/services/graffiti' AS source_url),

  STRUCT('pw_graffiti_private_002' AS policy_id, 'Graffiti on Private Property – 30-Day Abatement'         AS title,
        'For private property, Public Works inspects and, if graffiti exists, issues a notice. Owners must remove graffiti within 30 days under Public Works Code Article 23 and notify when abated; hardship hearings may be requested within the notice window.' AS chunk_text,
        'Vandalism'              AS target_theme,
        'https://sfpublicworks.org/services/graffiti-private-property' AS source_url),

  STRUCT('sf_sidewalk_001'      AS policy_id, 'Sidewalk/Curb Problems – Reporting & Responsibility'        AS title,
        'Report cracked, lifted, or defective sidewalks/curbs via 311. Property owners are generally responsible for sidewalk maintenance and may work through the City’s Sidewalk Inspection and Repair Program. Permits and licensed contractors are required for certain repairs.' AS chunk_text,
        'Street/Sidewalk Defect' AS target_theme,
        'https://www.sf.gov/report-curb-and-sidewalk-problems' AS source_url),

  STRUCT('pw_sidewalk_permit_002' AS policy_id, 'Sidewalk Repair – Permit & Contractor Requirements'       AS title,
        'To repair sidewalks/curbs requiring replacement or excavation, owners must use a California-licensed A or C-8 contractor and secure required permits/bonds before work.' AS chunk_text,
        'Street/Sidewalk Defect' AS target_theme,
        'https://sfpublicworks.org/services/permits/sidewalk-repair' AS source_url),

  STRUCT('sfmta_abandoned_001'  AS policy_id, 'Abandoned Vehicle – 72-Hour Rule'                           AS title,
        'Vehicles left in the same public spot over 72 hours may be cited or towed. Report suspected abandoned vehicles via 311; if towed, contact the City’s impound contractor with plate, description, and location/date.' AS chunk_text,
        'Abandoned Vehicle'      AS target_theme,
        'https://www.sfmta.com/getting-around/drive-park/towed-vehicles' AS source_url),

  STRUCT('sf_streetlight_001'   AS policy_id, 'Streetlight Problems – What to Report'                      AS title,
        'Report streetlights that are out, flickering, dim, always on, or with exposed wires through 311. Treat exposed wiring as a hazard and escalate appropriately.' AS chunk_text,
        'Streetlight Out'        AS target_theme,
        'https://www.sf.gov/report-problem-streetlight' AS source_url),

  STRUCT('hsoc_001'             AS policy_id, 'Encampments – Coordinated Response (HSOC)'                  AS title,
        'Encampment-related requests are coordinated via the Healthy Streets Operations Center (HSOC) using a phased approach. 311 routes non-encampment issues (e.g., general street cleaning) to Public Works. Operations may involve offers of services before cleaning activities.' AS chunk_text,
        'Encampment'             AS target_theme,
        'https://sfcontroller.org/sites/default/files/Documents/Auditing/Review%%20of%%20the%%20Healthy%%20Streets%%20Operations%%20Center.pdf' AS source_url)
]) AS r;

MERGE `%s.%s.policy_chunks` AS tgt
USING policy_upserts AS src
ON tgt.policy_id = src.policy_id
WHEN MATCHED THEN
  UPDATE SET
    title       = src.title,
    chunk_text  = src.chunk_text,
    target_theme= src.target_theme,
    source_url  = src.source_url
WHEN NOT MATCHED THEN
  INSERT (policy_id, title, chunk_text, target_theme, source_url)
  VALUES (src.policy_id, src.title, src.chunk_text, src.target_theme, src.source_url);
