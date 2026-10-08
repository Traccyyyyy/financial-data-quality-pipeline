# Execution evidence and reconciliation notes

## RBA source runs

**Run #1** (9 September 2026): SUCCESS; 21,298 staged, 18,182 valid, 3,116 invalid; invalid-rate 14.63%; 18,182 NEW; count reconciliation true.

**Run #10** (8 October 2026): SUCCESS; 21,758 staged, 18,602 valid, 3,156 invalid; invalid-rate 14.51%; 420 NEW, 0 CHANGED, 18,182 UNCHANGED; count reconciliation true.

The read-only monitoring query returned both runs from PostgreSQL. Note: Run #1 `last_attempt_at` postdates `completed_at`; the former is **not** a reliable first-start time for calculating execution duration.

## Supplier-scale synthetic SQL drill

Execution output: 300,000 source rows, 5,000 duplicate business keys, 10,000 duplicate-affected rows, 5,000 excess duplicate rows, 10,000 invalid key rows, 280,000 clean supplier rows, 45,000 source-only, 25,000 changed, 210,000 unchanged. Both `raw_reconciles` and `clean_reconciles` were true. The SQL node reported success in 5.058 s; this is not a total ingestion benchmark.

## Source of evidence

- n8n workflow JSON supplied by the project author.
- User-provided execution outputs and screenshots from October 2026.
- No live database connection or independently repeated execution was used to produce this documentation.
