-- Demonstration allocation counts; execute alongside 07, not a shipping authorization.
DECLARE control_assigned INT64 DEFAULT 315;
DECLARE treatment_assigned INT64 DEFAULT 315;
DECLARE expected_treatment_fraction FLOAT64 DEFAULT 0.5;
DECLARE alpha FLOAT64 DEFAULT 0.05;
DECLARE baseline_rate FLOAT64 DEFAULT 0.1175;
DECLARE minimum_absolute_lift FLOAT64 DEFAULT 0.04;
-- Fixed-design planning uses 1.96 (two-sided alpha .05), .842 (80% power).
ASSERT control_assigned>0 AND treatment_assigned>0 AS 'Empty assignment arm';
ASSERT expected_treatment_fraction>0 AND expected_treatment_fraction<1 AS 'Invalid allocation fraction';
ASSERT alpha=0.05 AS 'Planning constants assume alpha .05';
ASSERT baseline_rate>0 AND baseline_rate<1 AND minimum_absolute_lift>0 AND baseline_rate+minimum_absolute_lift<1 AS 'Invalid planning rates';
WITH expected AS (
 SELECT (control_assigned+treatment_assigned)*expected_treatment_fraction AS expected_treatment,
 (control_assigned+treatment_assigned)*(1-expected_treatment_fraction) AS expected_control
), checks AS (
 SELECT POW(treatment_assigned-expected_treatment,2)/expected_treatment+
 POW(control_assigned-expected_control,2)/expected_control AS allocation_chi_squared FROM expected
), planning AS (
 SELECT baseline_rate+minimum_absolute_lift AS p2,
 baseline_rate+minimum_absolute_lift/2 AS pbar
)
SELECT allocation_chi_squared,
 allocation_chi_squared>10.827566 AS sample_ratio_mismatch_at_alpha_001,
 CAST(CEIL(POW(1.96*SQRT(2*pbar*(1-pbar))+
 0.842*SQRT(baseline_rate*(1-baseline_rate)+p2*(1-p2)),2)/POW(minimum_absolute_lift,2)) AS INT64) AS approximate_required_per_arm,
 'Equal allocation planning; validate randomization, guardrails, stopping rule and visitor-level independence before inference' AS interpretation
FROM checks CROSS JOIN planning;
