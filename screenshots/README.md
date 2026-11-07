# Visualization setup

## Tableau

Create extracts from scripts 02–06. Build a KPI row for sessions, visitors, purchases and conversion; a stage bar chart; device and medium conversion tables with sample counts; and a cohort-age retention heatmap. Keep rates as fractions and display percentages. Show window dates, refresh time and partial-month status. Use sums of stage counts to recompute combined rates; never average segment conversion percentages.

## Amplitude

Use product-view, add-to-cart and purchase events with real event timestamps and the same session identity. Select session-level counting and strict event order where your plan supports them. If only user-level funnels are available, label them user funnels and do not claim parity with session SQL. Match dates, timezone, conversion window and identity before reconciling. Export retention events from the same lookback and use the same first-observed cohort rule; Amplitude's default first-ever event cohort may differ.

Do not shift timestamps merely to produce recent charts without disclosing the offset and preserving a canonical unshifted export. Account plan limitations may prevent historical analysis. Export your own aggregate screenshots after connecting the tools. No third-party screenshots or live dashboard links are bundled as evidence of this deployment.
