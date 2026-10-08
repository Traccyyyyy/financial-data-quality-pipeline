-- Extracted verbatim from n8n node: Upsert Validated Rates to Master
-- Requires project schema and, for $1 parameters, values supplied by n8n.
-- Do not execute write or cleanup statements against a live database without review.

WITH candidates AS (
    SELECT
        run_id,
        source,
        rate_date,
        series_id,
        rate,
        load_action
    FROM public.fx_rates_validated
    WHERE run_id = $1::BIGINT
      AND load_action IN ('NEW', 'CHANGED')
),
written AS (
    INSERT INTO public.fx_rates_master (
        source,
        rate_date,
        series_id,
        rate,
        first_loaded_run_id,
        last_changed_run_id
    )
    SELECT
        source,
        rate_date,
        series_id,
        rate,
        run_id,
        run_id
    FROM candidates
    ON CONFLICT (
        source,
        rate_date,
        series_id
    )
    DO UPDATE SET
        rate = EXCLUDED.rate,
        last_changed_run_id = EXCLUDED.last_changed_run_id,
        updated_at = NOW()
    WHERE public.fx_rates_master.rate
          IS DISTINCT FROM EXCLUDED.rate
    RETURNING
        source,
        rate_date,
        series_id
)
SELECT
    $1::BIGINT AS run_id,

    (
        SELECT COUNT(*)
        FROM public.fx_rates_validated
        WHERE run_id = $1::BIGINT
          AND load_action = 'NEW'
    )::INTEGER AS new_count,

    (
        SELECT COUNT(*)
        FROM public.fx_rates_validated
        WHERE run_id = $1::BIGINT
          AND load_action = 'CHANGED'
    )::INTEGER AS changed_count,

    (
        SELECT COUNT(*)
        FROM public.fx_rates_validated
        WHERE run_id = $1::BIGINT
          AND load_action = 'UNCHANGED'
    )::INTEGER AS unchanged_count,

    (
        SELECT COUNT(*)
        FROM written
    )::INTEGER AS writes_applied;
