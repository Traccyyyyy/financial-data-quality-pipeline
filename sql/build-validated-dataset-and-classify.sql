-- Extracted verbatim from n8n node: Build Validated Dataset and Classify
-- Requires project schema and, for $1 parameters, values supplied by n8n.
-- Do not execute write or cleanup statements against a live database without review.

WITH clean AS (
    SELECT
        s.staging_id,
        s.run_id,
        s.source,
        BTRIM(s.raw_rate_date)::DATE AS rate_date,
        BTRIM(s.series_id) AS series_id,
        BTRIM(s.raw_rate)::NUMERIC(20,8) AS rate
    FROM public.fx_rates_staging s
    WHERE s.run_id = $1::BIGINT
      AND NOT EXISTS (
          SELECT 1
          FROM public.dq_exceptions e
          WHERE e.run_id = s.run_id
            AND e.staging_id = s.staging_id
      )
),
classified AS (
    SELECT
        c.*,
        CASE
            WHEN m.source IS NULL
                THEN 'NEW'
            WHEN m.rate IS DISTINCT FROM c.rate
                THEN 'CHANGED'
            ELSE 'UNCHANGED'
        END AS load_action
    FROM clean c
    LEFT JOIN public.fx_rates_master m
      ON m.source = c.source
     AND m.rate_date = c.rate_date
     AND m.series_id = c.series_id
),
existing AS (
    SELECT
        staging_id,
        load_action
    FROM public.fx_rates_validated
    WHERE run_id = $1::BIGINT
),
inserted AS (
    INSERT INTO public.fx_rates_validated (
        run_id,
        staging_id,
        source,
        rate_date,
        series_id,
        rate,
        load_action
    )
    SELECT
        run_id,
        staging_id,
        source,
        rate_date,
        series_id,
        rate,
        load_action
    FROM classified
    ON CONFLICT (run_id, staging_id)
    DO NOTHING
    RETURNING
        staging_id,
        load_action
),
persisted AS (
    SELECT
        staging_id,
        load_action
    FROM existing

    UNION ALL

    SELECT
        staging_id,
        load_action
    FROM inserted
)
SELECT
    $1::BIGINT AS run_id,
    COUNT(*)::INTEGER AS accepted_count,
    COUNT(*) FILTER (
        WHERE load_action = 'NEW'
    )::INTEGER AS new_count,
    COUNT(*) FILTER (
        WHERE load_action = 'CHANGED'
    )::INTEGER AS changed_count,
    COUNT(*) FILTER (
        WHERE load_action = 'UNCHANGED'
    )::INTEGER AS unchanged_count,
    (
        SELECT COUNT(*)
        FROM inserted
    )::INTEGER AS newly_classified_count
FROM persisted;
