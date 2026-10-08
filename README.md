# Financial Data Quality & Reconciliation Pipeline

**n8n · PostgreSQL · SQL · Docker · RBA public foreign-exchange data**

An end-to-end, ETL-style workflow that fetches Reserve Bank of Australia (RBA) foreign-exchange data, transforms CSV records into a relational staging dataset, validates quality, tracks exceptions, classifies incremental changes and reconciles results against master data. A read-only SQL monitoring node reports historical outcomes.

**Scope:** Personal technical project and synthetic-data exercise; not an enterprise production system, distributed Spark/Databricks pipeline, or a commercial deployment.

## Verified results

| Measure | RBA run #1 · 9 Sep 2026 | RBA run #10 · 8 Oct 2026 |
|---|---:|---:|
| Staged records | 21,298 | 21,758 |
| Valid records | 18,182 | 18,602 |
| Invalid records | 3,116 | 3,156 |
| Invalid rate | 14.63% | 14.51% |
| NEW | 18,182 | 420 |
| CHANGED | 0 | 0 |
| UNCHANGED | 0 | 18,182 |
| Count reconciliation | **PASS** | **PASS** |
| Status | SUCCESS | SUCCESS |

**Incremental processing:** run #10 identified 18,182 existing valid records as unchanged and 420 additional valid records as new. The two displayed runs do **not** by themselves validate an updated-rate CHANGED case. A changed-source test/cleanup utility exists but is separate from the main pipeline.

### Synthetic supplier reconciliation drill

A standalone PostgreSQL SQL node in the same n8n project was re-executed successfully against **300,000 synthetic supplier rows** (query execution shown as ~5.06 seconds, excluding dataset generation and end-to-end ETL).

| Metric | Verified output |
|---|---:|
| Supplier rows | 300,000 |
| Duplicate business keys | 5,000 |
| Duplicate-affected rows | 10,000 |
| Invalid key rows | 10,000 |
| Clean supplier rows | 280,000 |
| SOURCE_ONLY | 45,000 |
| CHANGED | 25,000 |
| UNCHANGED | 210,000 |
| Raw reconciliation | **true** |
| Clean reconciliation | **true** |

Reconciliation checks: `300,000 = 10,000 + 10,000 + 280,000` and `280,000 = 45,000 + 25,000 + 210,000`.

These are deterministic synthetic data and SQL classification/reconciliation results. They are not evidence of Spark, distributed Big Data processing or production throughput.

![n8n pipeline overview](docs/images/01-pipeline-overview.png)

## Workflow architecture

```text
RBA CSV (HTTP)
    ↓
Extract CSV text → SHA fingerprint → register / resume run
    ↓                                 └─ already processed → stop
Strip metadata → Parse CSV → Normalize wide-to-long
    ↓
Package batch → PostgreSQL staging
    ↓
SQL data validation → exception records
    ↓
Validated dataset → NEW / CHANGED / UNCHANGED
    ↓
Conditional upsert to master
    ↓
Run summary → reconciliation checks

Read-only run monitoring: pipeline_runs → status, counts and invalid-rate history
Separate synthetic practice: seed 250k master / 300k supplier → SQL reconciliation
```

## Functional components

### 01 — Ingestion and source control

![Ingestion and source fingerprinting](docs/images/02-ingestion.png)

- Retrieve the public RBA foreign-exchange CSV.
- Fingerprint the source contents and record processing state in `pipeline_runs`.
- Skip reprocessing of an already successful source fingerprint and support resuming incomplete source runs.

### 02 — Transformation and data quality

![CSV normalisation, staging and validation](docs/images/03-transformation.png)

- Remove RBA metadata, parse CSV rows, normalize series into long-form records.
- Insert into PostgreSQL `fx_rates_staging`.
- Validate dates, series IDs, rates, non-finite values and duplicated business keys.
- Record quality issues in `dq_exceptions` instead of silently discarding records.

### 03 — Reconciliation and controlled load

![Incremental classification and reconciliation](docs/images/04-reconciliation.png)

- Classify valid records as NEW, CHANGED or UNCHANGED relative to `fx_rates_master`.
- Write only NEW/CHANGED candidates with conditional SQL upsert.
- Store run-level counters and check reconciliations and key uniqueness.

### 04 — Historical monitoring

![Read-only monitoring node](docs/images/05-monitoring-node.png)

![Historical RBA run monitoring output](docs/images/06-monitoring-results.png)

- Query persisted PostgreSQL `pipeline_runs` for the most recent RBA runs.
- Report status, staging/valid/invalid counts, invalid percentages and load classification.
- Verify `staged = valid + invalid` per run.
- Read-only: it does not rerun the ETL or write data.
- Monitoring reports one row per registered source fingerprint; it is **not** an exhaustive n8n execution-attempt log or a failure alerting system.

### 05 — Supplier-scale SQL drill

![300,000-record supplier reconciliation output](docs/images/07-supplier-reconciliation-results.png)

- Generate a repeatable **synthetic** 250,000-record reference/master set and 300,000-record source set.
- Detect repeated business keys and invalid keys.
- Reconcile clean records into SOURCE_ONLY / CHANGED / UNCHANGED categories.
- This is a **standalone practice node**, not part of the main automated RBA ingestion path.

## Files

- [Public-safe n8n workflow](workflows/rba-fx-data-quality-pipeline.json) — retains embedded SQL; credentials/instance metadata removed.
- [SQL files](sql/) — individual SQL queries extracted from the workflow for code review.
- [Monitoring SQL](sql/monitor-rba-run-history-read-only.sql) — historical result query.
- [Validation notes](docs/validation-results.md) — supplied run results and scope of verification.

## Setup and safety

1. Provision PostgreSQL with the project-specific tables and constraints: `pipeline_runs`, `fx_rates_staging`, `dq_exceptions`, `fx_rates_validated` and `fx_rates_master`.
2. Import the workflow JSON into n8n; configure your **own** PostgreSQL credentials.
3. The SQL files are reference copies of the embedded node queries. Some use n8n-supplied placeholders (`$1`, `$2`, etc.) and are **not** standalone schema-migration scripts.
4. The supplier seed and changed-source cleanup nodes are intentionally **disabled** in this public export. Review carefully before manually enabling: they contain bulk INSERT/DELETE/UPDATE statements.
5. Avoid running the full workflow against a real database without schema setup, backups and environment checks.

The export documents the implementation, but does not include Docker Compose, complete schema DDL, secrets or a turn-key database deployment.

## Limitations

- The RBA pipeline processes a public CSV file, not private banking/customer data.
- The synthetic supplier drill is SQL on PostgreSQL, not distributed big-data infrastructure.
- Run history reflects distinct registered source fingerprints, not every n8n execution attempt.
- No claim is made of Azure, Databricks, Fabric or production SLAs.
- Test outputs above were supplied from actual node executions; the public export has not been independently executed as a clean-room installation.
