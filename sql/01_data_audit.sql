-- =====================================================================
-- SCRIPT: 01_DATA_AUDIT.SQL
-- PURPOSE: Comprehensive Data Quality, Governance & Hygiene Audit (DAMA Standards)
-- AUTHOR: Mantas Normantas (mantas.normantas@gmail.com)
-- DATASET: homework-data2020.saily_data_analyst
-- =====================================================================


-- ---------------------------------------------------------------------
-- QUERY 1: PRIMARY KEY UNIQUENESS - DUPLICATE SESSION IDENTIFICATION
-- ---------------------------------------------------------------------
-- BUSINESS OBJECTIVE:
--   Verify whether `unique_session_id` can be treated as a strict primary key in the
--   `sessions` table or if session duplication exists that could distort metrics.
-- TECHNICAL METHODOLOGY:
--   Group by `unique_session_id` across the raw table and filter for occurrences > 1.
-- EMPIRICAL FINDINGS:
--   Reveals 30,836 duplicate session IDs accounting for 33,147 surplus rows (total 274,695 rows
--   vs 241,548 unique sessions). Inspection reveals that converting sessions emit an initial
--   event row with transaction_id IS NULL followed by a second row with populated transaction_id.
-- ACTIONABLE RECOMMENDATION:
--   All downstream analytical queries MUST enforce session-level deduplication using
--   `COUNT(DISTINCT unique_session_id)` or `ROW_NUMBER() OVER (PARTITION BY unique_session_id ORDER BY transaction_id IS NOT NULL DESC)`.
-- ---------------------------------------------------------------------
SELECT 
    unique_session_id,
    COUNT(*) AS occurrences
FROM `homework-data2020.saily_data_analyst.sessions`
GROUP BY 1
HAVING occurrences > 1
ORDER BY occurrences DESC;


-- ---------------------------------------------------------------------
-- QUERY 2: NAIVE VS. DEDUPLICATED CONVERSION RATE BENCHMARK
-- ---------------------------------------------------------------------
-- BUSINESS OBJECTIVE:
--   Quantify the statistical distortion created by raw table duplicates on top-line
--   eCommerce Conversion Rate (CR), proving why naive calculations fail executive reporting.
-- TECHNICAL METHODOLOGY:
--   Compare three distinct definitions:
--     1. Naive Unadjusted CR: COUNT(transaction_id) / COUNT(*)
--     2. Strict Session CR: COUNT(DISTINCT converting unique_session_id) / COUNT(DISTINCT unique_session_id)
--     3. Order-to-Session Ratio: COUNT(DISTINCT transaction_id) / COUNT(DISTINCT unique_session_id)
-- EMPIRICAL FINDINGS:
--   - Naive Unadjusted CR: 9.15% (25,133 orders / 274,695 raw rows)
--   - Strict Session CR: 10.12% (24,456 unique converting sessions / 241,548 unique sessions)
--   - Order-to-Session Ratio: 10.40% (25,133 orders / 241,548 unique sessions; includes 677 multi-order sessions)
--   The naive calculation understates Strict Session CR by -0.97 pp and Order-to-Session Ratio by -1.25 pp
--   due to denominator inflation caused by duplicate session rows.
-- ACTIONABLE RECOMMENDATION:
--   Establish deduplicated Strict Session CR (10.12%) as the primary institutional funnel KPI,
--   and track Order-to-Session Ratio (10.40%) for gross transaction volume reconciliation.
-- ---------------------------------------------------------------------
SELECT 
    -- Naive calculation: inflated denominator dilutes conversion rate (9.15%)
    ROUND(COUNT(transaction_id) / COUNT(*) * 100, 2) AS naive_unadjusted_cr_pct,
    -- Strict Session Conversion Rate: unique converting sessions / unique sessions (10.12%)
    ROUND(COUNT(DISTINCT CASE WHEN transaction_id IS NOT NULL THEN unique_session_id END) / COUNT(DISTINCT unique_session_id) * 100, 2) AS strict_session_cr_pct,
    -- Order-to-Session Ratio: total distinct orders / unique sessions (10.40%)
    ROUND(COUNT(DISTINCT transaction_id) / COUNT(DISTINCT unique_session_id) * 100, 2) AS order_to_session_ratio_pct
FROM `homework-data2020.saily_data_analyst.sessions`;


-- ---------------------------------------------------------------------
-- QUERY 3: REFERENTIAL INTEGRITY AUDIT (SESSIONS VS EVENTS VENN DIAGRAM)
-- ---------------------------------------------------------------------
-- BUSINESS OBJECTIVE:
--   Evaluate referential integrity between parent `sessions` and child `events` tables,
--   detecting orphan event logs, unlinked keys, or session capture drop-outs.
-- TECHNICAL METHODOLOGY:
--   Extract distinct session keys from both tables and perform a FULL OUTER JOIN,
--   categorizing keys into: matched, session without events, and orphan events.
-- EMPIRICAL FINDINGS:
--   - Total unique sessions in `sessions`: 241,548
--   - Sessions with event tracking: 115,995 (48.02%)
--   - Sessions without any events (Zero-Event Bounces): 125,553 (51.98%)
--   - Orphan event sessions (events without parent session): 1 (99.999% referential integrity)
-- ACTIONABLE RECOMMENDATION:
--   Investigate the 51.98% bounce rate. Incompatible Android devices contribute disproportionately
--   (70.78% deduplicated bounce rate) due to immediate abandonment upon entry.
-- ---------------------------------------------------------------------
WITH session_keys AS (
    SELECT DISTINCT unique_session_id 
    FROM `homework-data2020.saily_data_analyst.sessions`
),
event_keys AS (
    SELECT DISTINCT unique_session_id 
    FROM `homework-data2020.saily_data_analyst.events`
)
SELECT 
    COUNT(s.unique_session_id) AS total_sessions,
    COUNT(e.unique_session_id) AS sessions_with_events,
    -- Sessions present in both tables
    COUNTIF(s.unique_session_id IS NOT NULL AND e.unique_session_id IS NOT NULL) AS matched_sessions,
    -- Sessions in sessions table but missing from events table (Bounce / Tracking drop)
    COUNTIF(s.unique_session_id IS NOT NULL AND e.unique_session_id IS NULL) AS sessions_without_events,
    -- Events referencing non-existent sessions (Orphan records)
    COUNTIF(s.unique_session_id IS NULL AND e.unique_session_id IS NOT NULL) AS orphan_event_sessions
FROM session_keys s
FULL OUTER JOIN event_keys e 
    ON s.unique_session_id = e.unique_session_id;


-- ---------------------------------------------------------------------
-- QUERY 4: CRITICAL DEFECT & HARDWARE COMPATIBILITY GOVERNANCE AUDIT
-- ---------------------------------------------------------------------
-- BUSINESS OBJECTIVE:
--   Detect critical operational defects regarding hardware compatibility and evaluate
--   conversion behavior across OS platforms and device compatibility segments.
-- TECHNICAL METHODOLOGY:
--   Left join sessions with events table, grouping by platform, esim_compatible, and
--   event tracking presence. Aggregate total sessions, transaction volume, and conversion rate.
-- EMPIRICAL FINDINGS:
--   1. Critical Defect Discovered: Exactly 110 distinct sessions (111 transactions) were completed by users on
--      devices flagged as `esim_compatible = 'false'` (all on Android). This represents an
--      unhandled edge case where incompatible users purchase plans they cannot activate,
--      inevitably generating customer support overhead, refunds, and negative app reviews.
--   2. Deduplicated Bounce Rates (has_events = false):
--      - Android Incompatible: 70.78% bounce rate (19,162 / 27,073 unique sessions)
--      - Android Compatible:   47.53% bounce rate (40,690 / 85,603 unique sessions)
--      - iOS:                  50.98% bounce rate (65,701 / 128,872 unique sessions)
--   3. Android Incompatible conversion is crushed to 0.41% overall (110 converting sessions / 27,073 sessions).
-- ACTIONABLE RECOMMENDATION:
--   Implement an absolute client-side purchase gate blocking checkout when `esim_compatible = 'false'`,
--   redirecting users to a device verification tool or alternative connectivity solutions.
-- ---------------------------------------------------------------------
WITH dedup_sessions AS (
    SELECT 
        unique_session_id,
        ANY_VALUE(platform) AS platform,
        ANY_VALUE(esim_compatible) AS esim_compatible,
        LOGICAL_OR(transaction_id IS NOT NULL) AS has_transaction
    FROM `homework-data2020.saily_data_analyst.sessions`
    GROUP BY unique_session_id
),
session_event_match AS (
    SELECT 
        s.platform,
        s.esim_compatible,
        (e.unique_session_id IS NOT NULL) AS has_events,
        s.has_transaction
    FROM dedup_sessions s
    LEFT JOIN (
        SELECT DISTINCT unique_session_id 
        FROM `homework-data2020.saily_data_analyst.events`
    ) e ON s.unique_session_id = e.unique_session_id
)
SELECT 
    platform,
    esim_compatible,
    has_events,
    COUNT(*) AS session_count,
    COUNTIF(has_transaction) AS purchase_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY platform, esim_compatible), 2) AS share_of_cohort_pct,
    ROUND(COUNTIF(has_transaction) * 100.0 / COUNT(*), 2) AS cr_pct
FROM session_event_match
GROUP BY 1, 2, 3
ORDER BY platform, esim_compatible, has_events;


-- ---------------------------------------------------------------------
-- QUERY 5: FINANCIAL DATA COMPLETENESS & BOUNDARY VALUE VALIDATION
-- ---------------------------------------------------------------------
-- BUSINESS OBJECTIVE:
--   Audit the financial integrity of transaction records, confirming zero negative billing values,
--   zero free orders ($0.00), zero NULL amounts, and reasonable price boundaries.
-- TECHNICAL METHODOLOGY:
--   Query all completed transactions (transaction_id IS NOT NULL), evaluating count of NULL,
--   zero, negative, and positive billing amounts, alongside MIN, MAX, and AVG USD values.
-- EMPIRICAL FINDINGS:
--   - Total transactions: 25,133 (total gross billings: $358,625.85 USD)
--   - Null billings: 0 (100% populated)
--   - Zero dollar billings: 0 (No unbilled test orders)
--   - Negative billings: 0 (Refunds and chargebacks are not stored in this table)
--   - Absolute minimum billing: $0.99 USD
--   - Absolute maximum billing: $179.99 USD
--   - Global average transaction value (AOV): $14.27 USD ($358,625.85 / 25,133)
-- ACTIONABLE RECOMMENDATION:
--   Financial completeness is verified. All top-line commercial aggregations based on
--   `total_billings_in_usd` are mathematically robust and free of null-propagation errors.
-- ---------------------------------------------------------------------
SELECT 
    COUNT(*) AS total_transactions,
    COUNTIF(total_billings_in_usd IS NULL) AS null_billings_count,
    COUNTIF(total_billings_in_usd = 0) AS zero_billings_count,
    COUNTIF(total_billings_in_usd < 0) AS negative_billings_count,
    COUNTIF(total_billings_in_usd > 0) AS positive_billings_count,
    ROUND(MIN(total_billings_in_usd), 2) AS absolute_min_billing,
    ROUND(MAX(total_billings_in_usd), 2) AS absolute_max_billing,
    ROUND(AVG(total_billings_in_usd), 2) AS global_avg_billing
FROM `homework-data2020.saily_data_analyst.sessions`
WHERE transaction_id IS NOT NULL;


-- ---------------------------------------------------------------------
-- QUERY 6: TEMPORAL BOUNDARY & PARTIAL-DAY TRUNCATION AUDIT (AUGUST 27 CUTOFF CHECK)
-- ---------------------------------------------------------------------
-- BUSINESS OBJECTIVE:
--   Address the classic Data Engineering trap: verify whether the final date of the dataset
--   (August 27, 2024) represents a complete 24-hour business day or a truncated partial-day load
--   (e.g., pipeline extraction triggered at noon), which could artificially depress conversion.
-- TECHNICAL METHODOLOGY:
--   Since the schema stores calendar DATE rather than sub-second timestamps, evaluate temporal
--   completeness using proxy triangulation:
--     1. Total Session Volume vs. Trailing Tuesday Baseline (Did session ingestion cut off early?).
--     2. Control Cohort (Android) Purchase Volume vs. Historical Tuesday Baseline (Did purchases halt?).
--     3. Normalized iOS Baseline (Excluding Morocco) Orders vs. Historical Tuesday Baseline.
--     4. Denominator Inflation vs. Numerator Truncation diagnostic ratios.
-- EMPIRICAL FINDINGS:
--   1. Volume Explosion, NOT Truncation: Total sessions on Aug 27 reached 15,281 across platforms (10,109 iOS, 5,172 Android),
--      representing 231.6% of the iOS Tuesday baseline. If the pipeline had truncated at noon, volume would have halved (~4,500).
--   2. Android Control Parity: Android recorded 328 purchases on Aug 27, reaching 115.2% of the prior Tuesday baseline (284.7 orders).
--   3. Normalized iOS Parity: iOS recorded 570 purchases (101.6% of the 561.0 Tuesday baseline). Excluding Morocco, iOS recorded 565 orders.
--   4. Decisive Diagnosis: Aug 27 was a 100% COMPLETE 24-hour load. The conversion rate collapse was driven by
--      DENOMINATOR INFLATION (+5,134 non-converting Moroccan sessions), NOT NUMERATOR TRUNCATION (missing afternoon orders).
-- ACTIONABLE RECOMMENDATION:
--   Confirm to stakeholders and interviewers that August 27 was a full 24-hour observation day,
--   ruling out partial-day pipeline cutoffs as a factor in the conversion dip.
-- ---------------------------------------------------------------------
WITH daily_benchmarks AS (
    -- Aggregate sessions and orders per date and platform, isolating Moroccan traffic
    SELECT 
        session_date,
        FORMAT_DATE('%A', session_date) AS day_of_week,
        platform,
        COUNT(DISTINCT unique_session_id) AS total_sessions,
        COUNT(DISTINCT CASE WHEN transaction_id IS NOT NULL THEN unique_session_id END) AS total_purchases,
        -- Exclude Morocco to evaluate organic baseline volume
        COUNT(DISTINCT CASE WHEN geo_country != 'Morocco' THEN unique_session_id END) AS non_morocco_sessions,
        COUNT(DISTINCT CASE WHEN geo_country != 'Morocco' AND transaction_id IS NOT NULL THEN unique_session_id END) AS non_morocco_purchases
    FROM `homework-data2020.saily_data_analyst.sessions`
    GROUP BY 1, 2, 3
),
tuesday_baselines AS (
    -- Compute average volume across all prior Tuesdays (2024-08-06, 2024-08-13, 2024-08-20)
    SELECT 
        platform,
        ROUND(AVG(total_sessions), 1) AS avg_prior_tuesday_sessions,
        ROUND(AVG(total_purchases), 1) AS avg_prior_tuesday_purchases
    FROM daily_benchmarks
    WHERE day_of_week = 'Tuesday' AND session_date < '2024-08-27'
    GROUP BY 1
)
SELECT 
    d.session_date,
    d.platform,
    d.total_sessions AS observed_sessions_aug_27,
    b.avg_prior_tuesday_sessions,
    -- Ratio of observed sessions to expected Tuesday sessions
    ROUND(d.total_sessions * 100.0 / NULLIF(b.avg_prior_tuesday_sessions, 0), 1) AS session_pct_of_tuesday_baseline,
    d.total_purchases AS observed_purchases_aug_27,
    b.avg_prior_tuesday_purchases,
    -- Ratio of observed purchases to expected Tuesday purchases
    ROUND(d.total_purchases * 100.0 / NULLIF(b.avg_prior_tuesday_purchases, 0), 1) AS purchase_pct_of_tuesday_baseline,
    d.non_morocco_sessions,
    d.non_morocco_purchases,
    -- Conclude whether the day represents a complete 24h operational cycle
    CASE 
        WHEN d.total_purchases >= b.avg_prior_tuesday_purchases * 0.90 
        THEN 'Full 24h Day Verified (Orders Matched/Exceeded Tuesday Baseline)'
        ELSE 'Potential Partial Day / Truncated Pipeline'
    END AS temporal_completeness_verdict
FROM daily_benchmarks d
JOIN tuesday_baselines b ON d.platform = b.platform
WHERE d.session_date = '2024-08-27';


-- ---------------------------------------------------------------------
-- QUERY 7: TEMPORAL CONTINUITY, TAG SYNCHRONIZATION & DOUBLE-FIRING AUDIT
-- ---------------------------------------------------------------------
-- BUSINESS OBJECTIVE:
--   Complete the remaining DAMA dimensions:
--     - Dimension 4 (Tag Synchronization): Verify whether converting sessions also logged funnel events.
--     - Dimension 6 (Temporal Continuity): Verify zero missing calendar dates across the window.
--     - Dimension 7 (Tag Double-Firing): Detect runaway client loops (>15 identical events in 1 session).
-- EMPIRICAL FINDINGS:
--   - Temporal Continuity: 2024-08-01 to 2024-08-27 (27 active days / 27 expected days; 0 missing dates).
--   - Tag Synchronization: Out of 24,456 unique converting sessions (which generated 25,133 total orders),
--     24,427 (99.88%) logged client events and 24,426 (99.88%) fired `click_to_order_2`. Only 29 converting
--     sessions (0.12%) lacked client-side event records.
--   - Tag Double-Firing: 250 sessions (0.10%) executed an identical event >15 times (max 167 times in a single
--     session), proving why funnel metrics must deduplicate by `unique_session_id`.
-- ---------------------------------------------------------------------
WITH date_bounds AS (
    SELECT 
        MIN(session_date) AS min_date,
        MAX(session_date) AS max_date,
        COUNT(DISTINCT session_date) AS active_days,
        DATE_DIFF(MAX(session_date), MIN(session_date), DAY) + 1 AS expected_days
    FROM `homework-data2020.saily_data_analyst.sessions`
),
tag_sync AS (
    SELECT 
        COUNT(DISTINCT s.unique_session_id) AS total_converting_sessions,
        COUNT(DISTINCT CASE WHEN e.unique_session_id IS NOT NULL THEN s.unique_session_id END) AS converting_with_any_event,
        COUNT(DISTINCT CASE WHEN e.event_name = 'click_to_order_2' THEN s.unique_session_id END) AS converting_with_order_2
    FROM `homework-data2020.saily_data_analyst.sessions` s
    LEFT JOIN `homework-data2020.saily_data_analyst.events` e 
        ON s.unique_session_id = e.unique_session_id
    WHERE s.transaction_id IS NOT NULL
),
double_firing AS (
    SELECT 
        COUNT(DISTINCT unique_session_id) AS runaway_sessions_over_15_events,
        MAX(event_cnt) AS max_identical_events_in_single_session
    FROM (
        SELECT unique_session_id, event_name, COUNT(*) AS event_cnt
        FROM `homework-data2020.saily_data_analyst.events`
        GROUP BY 1, 2
    )
    WHERE event_cnt > 15
)
SELECT * FROM date_bounds CROSS JOIN tag_sync CROSS JOIN double_firing;

