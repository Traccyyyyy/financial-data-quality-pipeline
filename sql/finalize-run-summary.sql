-- Extracted verbatim from n8n node: Finalize Run Summary
-- Requires project schema and, for $1 parameters, values supplied by n8n.
-- Do not execute write or cleanup statements against a live database without review.

UPDATE public.pipeline_runs p
SET
    status = 'SUCCESS',

    completed_at = COALESCE(
        p.completed_at,
        NOW()
    ),

    source_row_count = (
        SELECT COUNT(DISTINCT s.source_row_no)
        FROM public.fx_rates_staging s
        WHERE s.run_id = p.run_id
    ),

    staged_record_count = (
        SELECT COUNT(*)
        FROM public.fx_rates_staging s
        WHERE s.run_id = p.run_id
    ),

    invalid_record_count = (
        SELECT COUNT(DISTINCT e.staging_id)
        FROM public.dq_exceptions e
        WHERE e.run_id = p.run_id
    ),

    valid_record_count = (
        SELECT COUNT(*)
        FROM public.fx_rates_validated v
        WHERE v.run_id = p.run_id
    ),

    new_record_count = (
        SELECT COUNT(*)
        FROM public.fx_rates_validated v
        WHERE v.run_id = p.run_id
          AND v.load_action = 'NEW'
    ),

    changed_record_count = (
        SELECT COUNT(*)
        FROM public.fx_rates_validated v
        WHERE v.run_id = p.run_id
          AND v.load_action = 'CHANGED'
    ),

    unchanged_record_count = (
        SELECT COUNT(*)
        FROM public.fx_rates_validated v
        WHERE v.run_id = p.run_id
          AND v.load_action = 'UNCHANGED'
    )

WHERE p.run_id = $1::BIGINT

RETURNING
    run_id,
    source,
    source_fingerprint,
    status,
    source_row_count,
    staged_record_count,
    invalid_record_count,
    valid_record_count,
    new_record_count,
    changed_record_count,
    unchanged_record_count,
    completed_at;
