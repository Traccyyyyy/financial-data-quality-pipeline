-- Extracted verbatim from n8n node: Load Batch to Staging
-- Requires project schema and, for $1 parameters, values supplied by n8n.
-- Do not execute write or cleanup statements against a live database without review.

WITH input_rows AS (
    SELECT *
    FROM jsonb_to_recordset($1::JSONB)
    AS x(
        source_row_no INTEGER,
        raw_rate_date TEXT,
        series_id TEXT,
        raw_rate TEXT,
        source TEXT
    )
),
inserted AS (
    INSERT INTO public.fx_rates_staging (
        run_id,
        source_row_no,
        raw_rate_date,
        series_id,
        raw_rate,
        source
    )
    SELECT
        $2::BIGINT,
        source_row_no,
        raw_rate_date,
        series_id,
        raw_rate,
        source
    FROM input_rows
    ON CONFLICT (
        run_id,
        source_row_no,
        series_id
    )
    DO NOTHING
    RETURNING staging_id
)
SELECT
    $2::BIGINT AS run_id,

    (
        SELECT COUNT(*)
        FROM input_rows
    )::INTEGER AS received_count,

    (
        SELECT COUNT(*)
        FROM inserted
    )::INTEGER AS inserted_count,

    (
        (
            SELECT COUNT(*)
            FROM input_rows
        )
        -
        (
            SELECT COUNT(*)
            FROM inserted
        )
    )::INTEGER AS duplicate_skipped;
