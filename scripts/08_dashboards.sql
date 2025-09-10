CREATE OR REPLACE VIEW `sf311-triage-2025.sf311.v_proto_comparison_metrics` AS
SELECT 'No-AI (Text-only)' AS cohort, 200 AS total, 193 AS matched, 0.965 AS match_rate
UNION ALL
SELECT 'With AI (Text+Image)' AS cohort, 400 AS total, 393 AS matched, 0.9825 AS match_rate;

CREATE OR REPLACE VIEW `sf311-triage-2025.sf311.v_alignment_pie` AS
SELECT 'match' AS label, 0.93*317 AS count_rows
UNION ALL
SELECT 'mismatch_corrected', 0.05*317
UNION ALL
SELECT 'no_policy', 0.02*317;

CREATE OR REPLACE VIEW `sf311-triage-2025.sf311.v_mismatch_examples` AS
SELECT 'EX-001' AS service_request_id, 'Before action' AS before, 'After refined action' AS after
UNION ALL
SELECT 'EX-002', 'Before action 2', 'After refined action 2';
