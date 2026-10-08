-- Extracted verbatim from n8n node: Monitor RBA Run History (Read Only)
-- Requires project schema and, for $1 parameters, values supplied by n8n.
-- Do not execute write or cleanup statements against a live database without review.

-- Read-only monitoring report. Run history is by unique source fingerprint,
-- not every n8n execution or duplicate-source skip.
WITH recent_runs AS (
  SELECT run_id, source, source_fingerprint, status,
         last_attempt_at, completed_at,
         staged_record_count, valid_record_count, invalid_record_count,
         new_record_count, changed_record_count, unchanged_record_count
  FROM public.pipeline_runs
  WHERE source = 'RBA'
  ORDER BY run_id DESC
  LIMIT 20
)
SELECT run_id, source, status, last_attempt_at, completed_at,
       COALESCE(staged_record_count, 0) AS staged_records,
       COALESCE(valid_record_count, 0) AS valid_records,
       COALESCE(invalid_record_count, 0) AS invalid_records,
       CASE WHEN COALESCE(staged_record_count,0) > 0
            THEN ROUND(100.0 * invalid_record_count / staged_record_count, 2)
            ELSE NULL END AS invalid_rate_pct,
       COALESCE(new_record_count, 0) AS new_records,
       COALESCE(changed_record_count, 0) AS changed_records,
       COALESCE(unchanged_record_count, 0) AS unchanged_records,
       CASE WHEN staged_record_count IS NULL THEN NULL
            ELSE staged_record_count = COALESCE(valid_record_count, 0)
                                       + COALESCE(invalid_record_count, 0)
       END AS counts_reconcile
FROM recent_runs
ORDER BY run_id DESC;
