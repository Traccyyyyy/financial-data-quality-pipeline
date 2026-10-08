-- Extracted verbatim from n8n node: Verify Run Reconciliation
-- Requires project schema and, for $1 parameters, values supplied by n8n.
-- Do not execute write or cleanup statements against a live database without review.

SELECT
    p.run_id,
    p.status,
    p.source_row_count,
    p.staged_record_count,
    p.invalid_record_count,
    p.valid_record_count,
    p.new_record_count,
    p.changed_record_count,
    p.unchanged_record_count,

    (
        p.staged_record_count
        =
        p.invalid_record_count
        +
        p.valid_record_count
    ) AS staging_reconciles,

    (
        SELECT
            COUNT(*)
            -
            COUNT(
                DISTINCT (
                    s.run_id,
                    s.source_row_no,
                    s.series_id
                )
            )
        FROM public.fx_rates_staging s
        WHERE s.run_id = p.run_id
    ) AS staging_duplicate_key_count,

    (
        SELECT
            COUNT(*)
            -
            COUNT(
                DISTINCT (
                    e.run_id,
                    e.staging_id,
                    e.error_code
                )
            )
        FROM public.dq_exceptions e
        WHERE e.run_id = p.run_id
    ) AS exception_duplicate_key_count,

    (
        SELECT
            COUNT(*)
            -
            COUNT(
                DISTINCT (
                    v.run_id,
                    v.source,
                    v.rate_date,
                    v.series_id
                )
            )
        FROM public.fx_rates_validated v
        WHERE v.run_id = p.run_id
    ) AS validated_duplicate_business_key_count,

    (
        SELECT
            COUNT(*)
            -
            COUNT(
                DISTINCT (
                    m.source,
                    m.rate_date,
                    m.series_id
                )
            )
        FROM public.fx_rates_master m
    ) AS master_duplicate_business_key_count

FROM public.pipeline_runs p

WHERE p.run_id = $1::BIGINT;
