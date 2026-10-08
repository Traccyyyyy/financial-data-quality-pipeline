-- Extracted verbatim from n8n node: Supplier Reconciliation SQL Practice
-- Requires project schema and, for $1 parameters, values supplied by n8n.
-- Do not execute write or cleanup statements against a live database without review.

WITH supplier AS (
    SELECT
        s.source,
        s.raw_rate_date,
        s.series_id,
        s.raw_rate
    FROM public.fx_rates_staging s
    JOIN public.pipeline_runs p
      ON p.run_id = s.run_id
    WHERE p.source = 'SUPPLIER_DRILL'
      AND p.source_fingerprint = REPEAT('b', 64)
),

duplicate_keys AS (
    SELECT
        source,
        raw_rate_date,
        series_id,
        COUNT(*) AS row_count
    FROM supplier
    GROUP BY
        source,
        raw_rate_date,
        series_id
    HAVING COUNT(*) > 1
),

duplicate_rows AS (
    SELECT s.*
    FROM supplier s
    JOIN duplicate_keys d
      ON d.source = s.source
     AND d.raw_rate_date = s.raw_rate_date
     AND d.series_id = s.series_id
),

non_duplicate_supplier AS (
    SELECT s.*
    FROM supplier s
    LEFT JOIN duplicate_keys d
      ON d.source = s.source
     AND d.raw_rate_date = s.raw_rate_date
     AND d.series_id = s.series_id
    WHERE d.series_id IS NULL
),

valid_series AS (
    SELECT DISTINCT
        series_id
    FROM public.fx_rates_master
    WHERE source = 'SUPPLIER_DRILL'
),

invalid_rows AS (
    SELECT s.*
    FROM non_duplicate_supplier s
    LEFT JOIN valid_series v
      ON v.series_id = s.series_id
    WHERE v.series_id IS NULL
),

clean_supplier AS (
    SELECT
        s.source,
        TO_DATE(
            BTRIM(s.raw_rate_date),
            'DD-Mon-YYYY'
        ) AS rate_date,
        s.series_id,
        BTRIM(s.raw_rate)::NUMERIC(20,8) AS rate
    FROM non_duplicate_supplier s
    JOIN valid_series v
      ON v.series_id = s.series_id
),

classified AS (
    SELECT
        s.*,
        CASE
            WHEN m.series_id IS NULL
                THEN 'SOURCE_ONLY'

            WHEN m.rate IS DISTINCT FROM s.rate
                THEN 'CHANGED'

            ELSE 'UNCHANGED'
        END AS reconciliation_status

    FROM clean_supplier s

    LEFT JOIN public.fx_rates_master m
      ON m.source = s.source
     AND m.rate_date = s.rate_date
     AND m.series_id = s.series_id
)

SELECT
    (SELECT COUNT(*) FROM supplier)
        AS supplier_rows,

    (SELECT COUNT(*) FROM duplicate_keys)
        AS duplicate_business_keys,

    (SELECT COUNT(*) FROM duplicate_rows)
        AS duplicate_affected_rows,

    (
        SELECT SUM(row_count - 1)
        FROM duplicate_keys
    ) AS excess_duplicate_rows,

    (SELECT COUNT(*) FROM invalid_rows)
        AS invalid_key_rows,

    (SELECT COUNT(*) FROM clean_supplier)
        AS clean_supplier_rows,

    COUNT(*) FILTER (
        WHERE reconciliation_status = 'SOURCE_ONLY'
    ) AS source_only_rows,

    COUNT(*) FILTER (
        WHERE reconciliation_status = 'CHANGED'
    ) AS changed_rows,

    COUNT(*) FILTER (
        WHERE reconciliation_status = 'UNCHANGED'
    ) AS unchanged_rows,

    (
        (SELECT COUNT(*) FROM supplier)
        =
        (SELECT COUNT(*) FROM duplicate_rows)
        +
        (SELECT COUNT(*) FROM invalid_rows)
        +
        (SELECT COUNT(*) FROM clean_supplier)
    ) AS raw_reconciles,

    (
        (SELECT COUNT(*) FROM clean_supplier)
        =
        COUNT(*) FILTER (
            WHERE reconciliation_status = 'SOURCE_ONLY'
        )
        +
        COUNT(*) FILTER (
            WHERE reconciliation_status = 'CHANGED'
        )
        +
        COUNT(*) FILTER (
            WHERE reconciliation_status = 'UNCHANGED'
        )
    ) AS clean_reconciles

FROM classified;
