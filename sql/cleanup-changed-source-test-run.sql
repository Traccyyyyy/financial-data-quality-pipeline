-- Extracted verbatim from n8n node: Cleanup Changed-Source Test Run
-- Requires project schema and, for $1 parameters, values supplied by n8n.
-- Do not execute write or cleanup statements against a live database without review.

BEGIN;

-- If run 6 changed any existing master records,
-- restore them from the original real run 1.
UPDATE public.fx_rates_master m
SET
    rate = baseline.rate,
    last_changed_run_id = 1,
    updated_at = NOW()
FROM public.fx_rates_validated baseline
WHERE baseline.run_id = 1
  AND m.last_changed_run_id = 6
  AND m.source = baseline.source
  AND m.rate_date = baseline.rate_date
  AND m.series_id = baseline.series_id;

-- Do not delete run 6 while master still references it.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM public.fx_rates_master
        WHERE first_loaded_run_id = 6
           OR last_changed_run_id = 6
    ) THEN
        RAISE EXCEPTION
            'Cleanup aborted: fx_rates_master still contains references to run 6';
    END IF;
END $$;

-- Deletes run 6 and cascades its staging / exception / validated rows.
DELETE FROM public.pipeline_runs
WHERE run_id = 6;

COMMIT;

-- Verify cleanup and restored master value.
SELECT
    EXISTS (
        SELECT 1
        FROM public.pipeline_runs
        WHERE run_id = 6
    ) AS run_6_still_exists,

    (
        SELECT rate
        FROM public.fx_rates_master
        WHERE source = 'RBA'
          AND rate_date = DATE '2023-01-03'
          AND series_id = 'FXRUSD'
    ) AS restored_fxrusd_rate,

    (
        SELECT first_loaded_run_id
        FROM public.fx_rates_master
        WHERE source = 'RBA'
          AND rate_date = DATE '2023-01-03'
          AND series_id = 'FXRUSD'
    ) AS first_loaded_run_id,

    (
        SELECT last_changed_run_id
        FROM public.fx_rates_master
        WHERE source = 'RBA'
          AND rate_date = DATE '2023-01-03'
          AND series_id = 'FXRUSD'
    ) AS last_changed_run_id,

    (
        SELECT COUNT(*)
        FROM public.fx_rates_staging
        WHERE run_id = 6
    ) AS run_6_staging_rows,

    (
        SELECT COUNT(*)
        FROM public.dq_exceptions
        WHERE run_id = 6
    ) AS run_6_exception_rows,

    (
        SELECT COUNT(*)
        FROM public.fx_rates_validated
        WHERE run_id = 6
    ) AS run_6_validated_rows;
