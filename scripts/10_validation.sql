DECLARE ok BOOL DEFAULT TRUE;

CREATE TEMP TABLE _metrics AS
SELECT * FROM `sf311-triage-2025.sf311.v_proto_comparison_metrics`;

SET ok = ok AND EXISTS (
  SELECT 1 FROM _metrics
  WHERE cohort = 'No-AI (Text-only)' AND total=200 AND matched=193 AND ABS(match_rate - 0.965) < 1e-6
);

SET ok = ok AND EXISTS (
  SELECT 1 FROM _metrics
  WHERE cohort = 'With AI (Text+Image)' AND total=400 AND matched=393 AND ABS(match_rate - 0.9825) < 1e-6
);

CREATE TEMP TABLE _pie AS
SELECT * FROM `sf311-triage-2025.sf311.v_alignment_pie`;

SET ok = ok AND (
  SELECT ABS(SUM(count_rows) - 317) < 1e-6 FROM _pie
);

IF ok THEN
  SELECT 'VALIDATION ✅ Passed' AS status;
ELSE
  SELECT 'VALIDATION ❌ Failed' AS status;
END IF;
