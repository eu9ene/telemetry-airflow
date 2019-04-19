WITH
  current_sample AS (
  SELECT
    -- Record the last day on which we received any FxA event at all from this user.
    DATE '{{ds}}' AS date_last_seen,
    -- Record the last day on which the user was in a "Tier 1" country;
    -- this allows a variant of country-segmented MAU where we can still count
    -- a user that appeared in one of the target countries in the previous
    -- 28 days even if the most recent "country" value is not in this set.
    IF(seen_in_tier1_country,
      DATE '{{ds}}',
      NULL) AS date_last_seen_in_tier1_country,
    * EXCEPT (submission_date,
      generated_time,
      seen_in_tier1_country)
  FROM
    telemetry.fxa_users_daily_v1
  WHERE
    submission_date = DATE '{{ds}}' ),
  previous AS (
  SELECT
    * EXCEPT (submission_date,
      generated_time)
      -- We use REPLACE to null out any last_seen observations older than 28 days;
      -- this ensures data never bleeds in from outside the target 28 day window.
      REPLACE (IF(date_last_seen_in_tier1_country > DATE_SUB(DATE '{{ds}}', INTERVAL 28 DAY),
          date_last_seen_in_tier1_country,
          NULL) AS date_last_seen_in_tier1_country)
  FROM
    telemetry.fxa_users_last_seen_v1
  WHERE
    submission_date = DATE_SUB(DATE '{{ds}}', INTERVAL 1 DAY)
    AND date_last_seen > DATE_SUB(DATE '{{ds}}', INTERVAL 28 DAY) )
SELECT
  DATE '{{ds}}' AS submission_date,
  CURRENT_DATETIME() AS generated_time,
  COALESCE(current_sample.date_last_seen,
    previous.date_last_seen) AS date_last_seen,
  COALESCE(current_sample.date_last_seen_in_tier1_country,
    previous.date_last_seen_in_tier1_country) AS date_last_seen_in_tier1_country,
  IF(current_sample.user_id IS NOT NULL,
    current_sample,
    previous).* EXCEPT (date_last_seen,
    date_last_seen_in_tier1_country)
FROM
  current_sample
FULL JOIN
  previous
USING
  (user_id)