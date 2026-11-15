# Tableau workbook

Run `bash ops/commerce.sh export` after publishing `dashboard_daily`, then open `commerce_analytics.twb` in Tableau Desktop or Tableau Public. The exporter writes three aggregate CSV files under `tableau/data/`: daily segment metrics, the full-sample funnel and January first-observed cohort retention. If Tableau asks to locate files, choose these generated files; relative path resolution depends on the desktop platform.

The workbook contains session, view, cart and purchase KPI sheets, daily conversion, conversion by device and medium, an ordered funnel and cohort retention. Conversion is the ratio of summed purchases to summed sessions. No visitor-level data or additive distinct-visitor KPI is exposed. The funnel and daily panels cover the complete public sample; retention covers the January 2017 cohort through June. Titles disclose the different windows. Daily publication timestamps remain in the export for freshness inspection.

The workbook is supplied as native Tableau XML, with named fields and calculations matching the SQL exports. XML and field dependencies can be checked locally; Tableau rendering and public publishing require a Tableau installation/account. Publish only after comparing workbook totals to SQL and checking missing/unknown categories. 
