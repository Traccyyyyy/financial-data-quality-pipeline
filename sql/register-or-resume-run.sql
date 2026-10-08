-- Extracted verbatim from n8n node: Register or Resume Run
-- Requires project schema and, for $1 parameters, values supplied by n8n.
-- Do not execute write or cleanup statements against a live database without review.

WITH resolved AS (
    INSERT INTO public.pipeline_runs (
        source,
        source_fingerprint,
        source_url,
        n8n_execution_id,
        status
    )
    VALUES (
        'RBA',
        $1,
        $2,
        $3,
        'IN_PROGRESS'
    )
    ON CONFLICT (source, source_fingerprint)
    DO UPDATE SET
        source_url = EXCLUDED.source_url,
        n8n_execution_id = EXCLUDED.n8n_execution_id,
        last_attempt_at = NOW()
    RETURNING
        run_id,
        source,
        source_fingerprint,
        status
)
SELECT
    run_id,
    source,
    source_fingerprint,
    status,
    (status <> 'SUCCESS') AS should_process
FROM resolved;
