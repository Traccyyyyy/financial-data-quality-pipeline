-- Extracted verbatim from n8n node: Validate Staging and Record Exceptions
-- Requires project schema and, for $1 parameters, values supplied by n8n.
-- Do not execute write or cleanup statements against a live database without review.

WITH base AS (
    SELECT
        s.*,
        NULLIF(BTRIM(s.raw_rate_date), '') AS clean_date_text,
        NULLIF(BTRIM(s.series_id), '') AS clean_series_id,
        NULLIF(BTRIM(s.raw_rate), '') AS clean_rate_text
    FROM public.fx_rates_staging s
    WHERE s.run_id = $1::BIGINT
),
typed AS (
    SELECT
        b.*,
        CASE
            WHEN clean_date_text IS NOT NULL
             AND clean_date_text ~ '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$'
             AND pg_input_is_valid(clean_date_text, 'date')
            THEN clean_date_text::DATE
            ELSE NULL
        END AS parsed_date,
        CASE
            WHEN clean_rate_text IS NOT NULL
             AND UPPER(clean_rate_text) NOT IN (
                 'NAN',
                 'INFINITY',
                 '+INFINITY',
                 '-INFINITY',
                 'INF',
                 '+INF',
                 '-INF'
             )
             AND pg_input_is_valid(
                 clean_rate_text,
                 'numeric(20,8)'
             )
            THEN clean_rate_text::NUMERIC(20,8)
            ELSE NULL
        END AS parsed_rate
    FROM base b
),
tagged AS (
    SELECT
        t.*,
        CASE
            WHEN parsed_date IS NOT NULL
             AND clean_series_id IS NOT NULL
            THEN COUNT(*) OVER (
                PARTITION BY
                    source,
                    parsed_date,
                    clean_series_id
            )
            ELSE 0
        END AS business_key_count
    FROM typed t
),
errors AS (
    SELECT
        t.run_id,
        t.staging_id,
        e.error_code,
        e.error_detail
    FROM tagged t
    CROSS JOIN LATERAL (
        VALUES
        (
            'MISSING_DATE',
            CASE
                WHEN t.clean_date_text IS NULL
                THEN 'raw_rate_date is null or blank'
            END
        ),
        (
            'INVALID_DATE_FORMAT',
            CASE
                WHEN t.clean_date_text IS NOT NULL
                 AND t.clean_date_text
                     !~ '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$'
                THEN 'Expected date format DD-Mon-YYYY'
            END
        ),
        (
            'INVALID_DATE_VALUE',
            CASE
                WHEN t.clean_date_text IS NOT NULL
                 AND t.clean_date_text
                     ~ '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$'
                 AND t.parsed_date IS NULL
                THEN 'Date text matches the expected format but is not a valid date'
            END
        ),
        (
            'MISSING_SERIES_ID',
            CASE
                WHEN t.clean_series_id IS NULL
                THEN 'series_id is null or blank'
            END
        ),
        (
            'INVALID_SERIES_ID',
            CASE
                WHEN t.clean_series_id IS NOT NULL
                 AND t.clean_series_id
                     !~ '^FXR[A-Z0-9]+$'
                THEN 'Unexpected RBA series_id format'
            END
        ),
        (
            'MISSING_RATE',
            CASE
                WHEN t.clean_rate_text IS NULL
                THEN 'raw_rate is null or blank'
            END
        ),
        (
            'NON_FINITE_RATE',
            CASE
                WHEN t.clean_rate_text IS NOT NULL
                 AND UPPER(t.clean_rate_text) IN (
                     'NAN',
                     'INFINITY',
                     '+INFINITY',
                     '-INFINITY',
                     'INF',
                     '+INF',
                     '-INF'
                 )
                THEN 'Rate is non-finite'
            END
        ),
        (
            'INVALID_RATE',
            CASE
                WHEN t.clean_rate_text IS NOT NULL
                 AND UPPER(t.clean_rate_text) NOT IN (
                     'NAN',
                     'INFINITY',
                     '+INFINITY',
                     '-INFINITY',
                     'INF',
                     '+INF',
                     '-INF'
                 )
                 AND NOT pg_input_is_valid(
                     t.clean_rate_text,
                     'numeric(20,8)'
                 )
                THEN 'Rate cannot be converted to NUMERIC(20,8)'
            END
        ),
        (
            'NON_POSITIVE_RATE',
            CASE
                WHEN t.parsed_rate IS NOT NULL
                 AND t.parsed_rate <= 0
                THEN 'Rate must be greater than zero'
            END
        ),
        (
            'DUPLICATE_BUSINESS_KEY',
            CASE
                WHEN t.business_key_count > 1
                THEN 'Duplicate (source, rate_date, series_id) exists inside this source run'
            END
        )
    ) AS e(
        error_code,
        error_detail
    )
    WHERE e.error_detail IS NOT NULL
),
inserted AS (
    INSERT INTO public.dq_exceptions (
        run_id,
        staging_id,
        error_code,
        error_detail
    )
    SELECT
        run_id,
        staging_id,
        error_code,
        error_detail
    FROM errors
    ON CONFLICT (
        run_id,
        staging_id,
        error_code
    )
    DO NOTHING
    RETURNING exception_id
)
SELECT
    $1::BIGINT AS run_id,

    (
        SELECT COUNT(DISTINCT staging_id)
        FROM errors
    )::INTEGER AS invalid_record_count,

    (
        SELECT COUNT(*)
        FROM errors
    )::INTEGER AS detected_error_count,

    (
        SELECT COUNT(*)
        FROM inserted
    )::INTEGER AS newly_inserted_exception_count;
