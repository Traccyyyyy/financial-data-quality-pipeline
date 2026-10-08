-- Extracted verbatim from n8n node: Seed Supplier Scale Drill
-- Requires project schema and, for $1 parameters, values supplied by n8n.
-- Do not execute write or cleanup statements against a live database without review.

BEGIN;

-- Remove any previous copy of the supplier-scale practice dataset.
DELETE FROM public.fx_rates_master
WHERE source = 'SUPPLIER_DRILL';

DELETE FROM public.pipeline_runs
WHERE source = 'SUPPLIER_DRILL';


-- ============================================================
-- 1. CREATE A 250,000-ROW MASTER DATASET
-- ============================================================

-- Create one completed logical run to provide lineage
-- for the synthetic master records.
INSERT INTO public.pipeline_runs (
    source,
    source_fingerprint,
    source_url,
    status,
    completed_at
)
VALUES (
    'SUPPLIER_DRILL',
    REPEAT('a', 64),
    'synthetic://supplier-drill/master-250k',
    'SUCCESS',
    NOW()
);


-- 250 dates × 1,000 series = 250,000 master records.
INSERT INTO public.fx_rates_master (
    source,
    rate_date,
    series_id,
    rate,
    first_loaded_run_id,
    last_changed_run_id
)
SELECT
    'SUPPLIER_DRILL',
    DATE '2025-01-01' + d,
    'FXR' || LPAD(s::TEXT, 6, '0'),

    (
        1
        + d * 0.0001
        + s * 0.000001
    )::NUMERIC(20,8),

    r.run_id,
    r.run_id

FROM generate_series(0, 249) AS d

CROSS JOIN generate_series(1, 1000) AS s

CROSS JOIN LATERAL (
    SELECT run_id
    FROM public.pipeline_runs
    WHERE source = 'SUPPLIER_DRILL'
      AND source_fingerprint = REPEAT('a', 64)
) AS r;


-- ============================================================
-- 2. CREATE THE 300,000-ROW SUPPLIER SOURCE RUN
-- ============================================================

INSERT INTO public.pipeline_runs (
    source,
    source_fingerprint,
    source_url,
    status
)
VALUES (
    'SUPPLIER_DRILL',
    REPEAT('b', 64),
    'synthetic://supplier-drill/source-300k',
    'IN_PROGRESS'
);


-- ============================================================
-- 3. LOAD 300,000 SUPPLIER ROWS INTO STAGING
-- ============================================================

WITH supplier_run AS (

    SELECT run_id
    FROM public.pipeline_runs
    WHERE source = 'SUPPLIER_DRILL'
      AND source_fingerprint = REPEAT('b', 64)

),

rows_to_insert AS (

    -- --------------------------------------------------------
    -- A. 210,000 UNCHANGED MATCHES
    -- --------------------------------------------------------

    SELECT
        (d * 1000 + s)::INTEGER AS source_row_no,

        TO_CHAR(
            DATE '2025-01-01' + d,
            'DD-Mon-YYYY'
        ) AS raw_rate_date,

        'FXR' || LPAD(s::TEXT, 6, '0')
            AS series_id,

        (
            1
            + d * 0.0001
            + s * 0.000001
        )::NUMERIC(20,8)::TEXT
            AS raw_rate,

        'SUPPLIER_DRILL'::TEXT
            AS source

    FROM generate_series(0, 209) AS d
    CROSS JOIN generate_series(1, 1000) AS s


    UNION ALL


    -- --------------------------------------------------------
    -- B. 25,000 CHANGED MATCHES
    -- Same business keys as master, rate differs by +0.01.
    -- --------------------------------------------------------

    SELECT
        (
            210000
            + (d - 210) * 1000
            + s
        )::INTEGER,

        TO_CHAR(
            DATE '2025-01-01' + d,
            'DD-Mon-YYYY'
        ),

        'FXR' || LPAD(s::TEXT, 6, '0'),

        (
            1
            + d * 0.0001
            + s * 0.000001
            + 0.01
        )::NUMERIC(20,8)::TEXT,

        'SUPPLIER_DRILL'::TEXT

    FROM generate_series(210, 234) AS d
    CROSS JOIN generate_series(1, 1000) AS s


    UNION ALL


    -- --------------------------------------------------------
    -- C1. FIRST COPY OF 5,000 DUPLICATE BUSINESS KEYS
    -- --------------------------------------------------------

    SELECT
        (
            235000
            + (d - 235) * 1000
            + s
        )::INTEGER,

        TO_CHAR(
            DATE '2025-01-01' + d,
            'DD-Mon-YYYY'
        ),

        'FXR' || LPAD(s::TEXT, 6, '0'),

        (
            1
            + d * 0.0001
            + s * 0.000001
        )::NUMERIC(20,8)::TEXT,

        'SUPPLIER_DRILL'::TEXT

    FROM generate_series(235, 239) AS d
    CROSS JOIN generate_series(1, 1000) AS s


    UNION ALL


    -- --------------------------------------------------------
    -- C2. SECOND COPY OF THE SAME 5,000 KEYS
    --
    -- Result:
    -- 5,000 duplicate business keys
    -- 10,000 affected rows
    -- --------------------------------------------------------

    SELECT
        (
            240000
            + (d - 235) * 1000
            + s
        )::INTEGER,

        TO_CHAR(
            DATE '2025-01-01' + d,
            'DD-Mon-YYYY'
        ),

        'FXR' || LPAD(s::TEXT, 6, '0'),

        (
            1
            + d * 0.0001
            + s * 0.000001
        )::NUMERIC(20,8)::TEXT,

        'SUPPLIER_DRILL'::TEXT

    FROM generate_series(235, 239) AS d
    CROSS JOIN generate_series(1, 1000) AS s


    UNION ALL


    -- --------------------------------------------------------
    -- D. 45,000 VALID SOURCE-ONLY RECORDS
    --
    -- These dates do not exist in the 250k master.
    -- --------------------------------------------------------

    SELECT
        (
            245000
            + (d - 250) * 1000
            + s
        )::INTEGER,

        TO_CHAR(
            DATE '2025-01-01' + d,
            'DD-Mon-YYYY'
        ),

        'FXR' || LPAD(s::TEXT, 6, '0'),

        (
            1
            + d * 0.0001
            + s * 0.000001
        )::NUMERIC(20,8)::TEXT,

        'SUPPLIER_DRILL'::TEXT

    FROM generate_series(250, 294) AS d
    CROSS JOIN generate_series(1, 1000) AS s


    UNION ALL


    -- --------------------------------------------------------
    -- E. 10,000 INVALID BUSINESS KEYS
    --
    -- Date and rate are valid.
    -- Only series_id is deliberately invalid.
    -- --------------------------------------------------------

    SELECT
        (
            290000
            + (d - 295) * 1000
            + s
        )::INTEGER,

        TO_CHAR(
            DATE '2025-01-01' + d,
            'DD-Mon-YYYY'
        ),

        'BAD' || LPAD(s::TEXT, 6, '0'),

        (
            1
            + d * 0.0001
            + s * 0.000001
        )::NUMERIC(20,8)::TEXT,

        'SUPPLIER_DRILL'::TEXT

    FROM generate_series(295, 304) AS d
    CROSS JOIN generate_series(1, 1000) AS s
)


INSERT INTO public.fx_rates_staging (
    run_id,
    source_row_no,
    raw_rate_date,
    series_id,
    raw_rate,
    source
)

SELECT
    sr.run_id,
    r.source_row_no,
    r.raw_rate_date,
    r.series_id,
    r.raw_rate,
    r.source

FROM rows_to_insert r
CROSS JOIN supplier_run sr;


COMMIT;


-- ============================================================
-- VERIFY THE PRACTICE DATASET
-- ============================================================

SELECT

    (
        SELECT run_id
        FROM public.pipeline_runs
        WHERE source = 'SUPPLIER_DRILL'
          AND source_fingerprint = REPEAT('a', 64)
    ) AS baseline_run_id,

    (
        SELECT run_id
        FROM public.pipeline_runs
        WHERE source = 'SUPPLIER_DRILL'
          AND source_fingerprint = REPEAT('b', 64)
    ) AS supplier_run_id,

    (
        SELECT COUNT(*)
        FROM public.fx_rates_master
        WHERE source = 'SUPPLIER_DRILL'
    ) AS master_rows,

    (
        SELECT COUNT(*)

        FROM public.fx_rates_staging s

        JOIN public.pipeline_runs p
          ON p.run_id = s.run_id

        WHERE p.source = 'SUPPLIER_DRILL'
          AND p.source_fingerprint = REPEAT('b', 64)

    ) AS supplier_rows;
