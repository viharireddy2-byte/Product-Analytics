-- Demonstration counts only: not an executed randomized experiment.
DECLARE control_n INT64 DEFAULT 315;
DECLARE treatment_n INT64 DEFAULT 315;
DECLARE control_conversions INT64 DEFAULT 37;
DECLARE treatment_conversions INT64 DEFAULT 50;
ASSERT control_n > 0 AND treatment_n > 0 AS 'Positive sample sizes required';
ASSERT control_conversions BETWEEN 0 AND control_n AND treatment_conversions BETWEEN 0 AND treatment_n AS 'Invalid conversions';
WITH rates AS (
 SELECT SAFE_DIVIDE(control_conversions,control_n) c,
 SAFE_DIVIDE(treatment_conversions,treatment_n) t,
 SAFE_DIVIDE(control_conversions+treatment_conversions,control_n+treatment_n) pooled
), stats AS (
 SELECT *, SQRT(pooled*(1-pooled)*(1.0/control_n+1.0/treatment_n)) pooled_se,
 SQRT(c*(1-c)/control_n+t*(1-t)/treatment_n) difference_se FROM rates
)
SELECT c AS control_rate, t AS treatment_rate, t-c AS absolute_lift,
 SAFE_DIVIDE(t-c,c) AS relative_lift,
 SAFE_DIVIDE(t-c,pooled_se) AS z_score,
 t-c-1.96*difference_se AS lift_ci_low, t-c+1.96*difference_se AS lift_ci_high,
 CASE WHEN pooled_se=0 THEN 'insufficient variance'
 WHEN LEAST(control_conversions,control_n-control_conversions,treatment_conversions,treatment_n-treatment_conversions)<5 THEN 'sparse counts: use exact inference'
 WHEN ABS(SAFE_DIVIDE(t-c,pooled_se))>1.96 THEN 'significant at two-sided alpha 0.05'
 ELSE 'inconclusive' END AS decision
FROM stats;
