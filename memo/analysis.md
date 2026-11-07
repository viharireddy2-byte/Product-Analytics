# Analysis and decision guide

Start with session coverage and the unordered-event diagnostics. Investigate large changes in missing funnel steps before attributing them to product behavior. Strict stage counts must satisfy purchases ≤ carts ≤ views ≤ sessions.

Compare device and medium conversion using both volume and rates. Aggregate conversion can shift because of traffic mix; a lower rate alone does not establish the cause. Prioritize a segment only after reviewing its sample size, instrumentation, and business value. Medium is a source attribute, not causal marketing attribution.

Retention is first-observed visitor activity. A returning browser need not be a returning buyer; cookie resets and cross-device activity affect identity. Exclude partial months from comparisons and use the full available lookback. Test post-purchase retention hypotheses separately from this activity cohort.

The demonstration experiment uses 37/315 control conversions and 50/315 treatment conversions: 11.75% versus 15.87%, approximately +4.13 percentage points. The unpooled normal 95% interval is approximately -1.25 to +9.51 percentage points. It crosses zero, so the result is inconclusive. These inputs illustrate inference and do not establish a checkout improvement. Define assignment, primary metric, minimum detectable effect, required sample size, guardrails, and stopping rule before collecting real experiment data.
