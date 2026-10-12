-- =====================================================================
-- SCRIPT: 03_ANOMALIES_AND_CORRIDORS.SQL
-- PURPOSE: Dual-Anomaly Deconstruction (Aug 27 Crash & Aug 16 Peak), Global Corridors & Simpson's Paradox
-- AUTHOR: Mantas Normantas (mantas.normantas@gmail.com)
-- DATASET: homework-data2020.saily_data_analyst
-- =====================================================================


-- ---------------------------------------------------------------------
-- QUERY 1: NEGATIVE ANOMALY - AUGUST 27 IOS CRASH COUNTRY-LEVEL DECOMPOSITION
-- ---------------------------------------------------------------------
-- BUSINESS OBJECTIVE:
--   Isolate the exact geographic driver behind the severe iOS conversion rate collapse on
--   August 27, 2024, where iOS CR crashed to 5.64% despite normal app infrastructure health.
-- TECHNICAL METHODOLOGY:
--   Filter sessions strictly for session_date = '2024-08-27' and platform = 'IOS',
--   aggregating distinct sessions, completed purchases, and conversion rate by `geo_country`.
-- EMPIRICAL FINDINGS:
--   - Morocco (`geo_country = 'Morocco'`) exploded to 5,134 iOS sessions on this single date,
--     generating a meager 5 purchases (**0.10% Conversion Rate**).
--   - Excluding Morocco, all other iOS markets on August 27 generated 4,975 sessions and 565 purchases (11.36% CR).
--   - Morocco alone accounted for over 50.8% of all iOS sessions on August 27, mechanically
--     depressing the global iOS conversion rate from 11.36% down to 5.64% (570 / 10,109).
-- ACTIONABLE RECOMMENDATION:
--   Alert the Performance Marketing and UA teams: check external ad campaign bid pacing, affiliate
--   fraud, or viral social media referral traffic originating within Morocco.
-- ---------------------------------------------------------------------
SELECT 
    geo_country,
    COUNT(DISTINCT unique_session_id) AS sessions_on_aug_27,
    COUNT(DISTINCT CASE WHEN transaction_id IS NOT NULL THEN unique_session_id END) AS purchases,
    ROUND(
        COUNT(DISTINCT CASE WHEN transaction_id IS NOT NULL THEN unique_session_id END) * 100.0 / 
        COUNT(DISTINCT unique_session_id), 
        2
    ) AS cr_pct
FROM `homework-data2020.saily_data_analyst.sessions`
WHERE session_date = '2024-08-27' 
  AND platform = 'IOS'
GROUP BY 1
ORDER BY sessions_on_aug_27 DESC
LIMIT 10;


-- ---------------------------------------------------------------------
-- QUERY 2: LONGITUDINAL TRAJECTORY OF MOROCCO TRAFFIC (AUG 01 - AUG 27)
-- ---------------------------------------------------------------------
-- BUSINESS OBJECTIVE:
--   Determine whether the Moroccan traffic surge was an acute one-day phenomenon or part of a
--   multi-day viral / paid campaign ramp-up.
-- TECHNICAL METHODOLOGY:
--   Extract Moroccan sessions over time across all platforms, tracking session volume,
--   purchases, and conversion rate day by day.
-- EMPIRICAL FINDINGS:
--   - Historical baseline (Aug 01 - Aug 20): Morocco averaged ~180 sessions/day with a healthy ~10.5% CR (~12 purchases/day).
--   - Exponential Ramp (Aug 22 - Aug 26): Traffic expanded rapidly (180 -> 650 -> 1,723 -> 2,800+ sessions/day) while purchases stayed flat at 6-9.
--   - Climax (Aug 27): Traffic peaked at 5,787 total sessions (5,134 on iOS) with 0.10% iOS CR.
-- ACTIONABLE RECOMMENDATION:
--   Implement automated anomaly alerts on geographic session spikes with near-zero conversion to pause runaway ad spend.
-- ---------------------------------------------------------------------
SELECT 
    session_date,
    COUNT(DISTINCT unique_session_id) AS morocco_sessions,
    COUNT(DISTINCT CASE WHEN transaction_id IS NOT NULL THEN unique_session_id END) AS morocco_purchases,
    ROUND(
        COUNT(DISTINCT CASE WHEN transaction_id IS NOT NULL THEN unique_session_id END) * 100.0 / 
        COUNT(DISTINCT unique_session_id), 
        2
    ) AS morocco_cr_pct
FROM `homework-data2020.saily_data_analyst.sessions`
WHERE geo_country = 'Morocco'
GROUP BY 1
ORDER BY session_date;


-- ---------------------------------------------------------------------
-- QUERY 3: DESTINATION BROWSING INTENT OF MOROCCAN SESSIONS ON AUGUST 27
-- ---------------------------------------------------------------------
-- BUSINESS OBJECTIVE:
--   Uncover user intent during the Moroccan surge: were these international travelers seeking
--   eSIMs abroad, or domestic Moroccan locals seeking cheap local mobile data?
-- TECHNICAL METHODOLOGY:
--   Join sessions with events table for Moroccan sessions on August 27, aggregating
--   by `plan_destination` to identify which destination plans were viewed.
-- EMPIRICAL FINDINGS:
--   - Across all 5,787 Moroccan sessions (iOS + Android) on August 27, 5,134 session-destination pairs
--     were logged in `events`, of which 5,019 distinct sessions (97.8% of destination-browsing Moroccan sessions)
--     searched strictly for domestic data in Morocco (`plan_destination = 'MA'`).
--   - All international travel destinations combined (US, TR, ES, etc.) accounted for only 115 sessions.
--   - Root Cause: Local Moroccans flooded the app looking for local internet data. Upon seeing
--     international tourist USD pricing compared to local domestic carrier rates, 99.9% abandoned.
-- ACTIONABLE RECOMMENDATION:
--   Exclude domestic traffic in non-target emerging markets from paid UA campaigns, or gate domestic plan ads.
-- ---------------------------------------------------------------------
SELECT 
    e.plan_destination,
    COUNT(*) AS total_events,
    COUNT(DISTINCT s.unique_session_id) AS distinct_sessions
FROM `homework-data2020.saily_data_analyst.sessions` s
JOIN `homework-data2020.saily_data_analyst.events` e 
    ON s.unique_session_id = e.unique_session_id
WHERE s.geo_country = 'Morocco' 
  AND s.session_date = '2024-08-27'
GROUP BY 1
ORDER BY distinct_sessions DESC
LIMIT 10;


-- ---------------------------------------------------------------------
-- QUERY 4: POSITIVE ANOMALY - AUGUST 16 PEAK PERFORMANCE (TOP 5 REVENUE DAYS)
-- ---------------------------------------------------------------------
-- BUSINESS OBJECTIVE:
--   Investigate the single highest revenue-generating day in the dataset (August 16, 2024)
--   and uncover macro calendar patterns across top sales days.
-- TECHNICAL METHODOLOGY:
--   Aggregate total purchases, revenue in USD, and average order value (AOV) grouped by
--   session_date and formatted day_of_week. Order by total purchases descending (Top 5).
-- EMPIRICAL FINDINGS:
--   - Top Day: August 16, 2024 (Friday) reached **$16,240.64 USD revenue and 1,130 orders** (AOV $14.37).
--   - Macro Calendar Pattern: All Top 5 days fall exclusively on Thursdays, Fridays, and Saturdays:
--       1. 2024-08-16 (Friday)   - 1,130 orders | $16,240.64 USD ($14.37 AOV)
--       2. 2024-08-24 (Saturday) - 1,035 orders | $15,663.55 USD ($15.13 AOV)
--       3. 2024-08-17 (Saturday) - 1,055 orders | $15,062.72 USD ($14.28 AOV)
--       4. 2024-08-23 (Friday)   - 1,060 orders | $15,039.64 USD ($14.19 AOV)
--       5. 2024-08-15 (Thursday) - 1,001 orders | $14,345.20 USD ($14.33 AOV)
-- ACTIONABLE RECOMMENDATION:
--   Schedule major promotional pushes and CRM push notifications on Thursday afternoon and Friday
--   morning to capitalize on the "Weekend Getaway Surge".
-- ---------------------------------------------------------------------
SELECT 
    session_date,
    FORMAT_DATE('%A', session_date) AS day_of_week,
    COUNT(transaction_id) AS total_purchases,
    ROUND(SUM(total_billings_in_usd), 2) AS total_revenue_usd,
    ROUND(SUM(total_billings_in_usd) / COUNT(transaction_id), 2) AS real_aov_usd
FROM `homework-data2020.saily_data_analyst.sessions`
GROUP BY 1, 2
ORDER BY total_revenue_usd DESC
LIMIT 5;


-- ---------------------------------------------------------------------
-- QUERY 5: AUGUST 16 PEAK - TOP REVENUE CORRIDORS & QUOTA MIX
-- ---------------------------------------------------------------------
-- BUSINESS OBJECTIVE:
--   Deconstruct the commercial engine of August 16 to understand which buyer origins, destinations,
--   and data quota tiers generated the peak revenue.
-- TECHNICAL METHODOLOGY:
--   Filter transactions on 2024-08-16, grouping by buyer country (`geo_country`), purchased destination
--   (`transaction_plan_destination`), and quota tier (`transaction_plan_quota`).
-- EMPIRICAL FINDINGS:
--   - North American corridors led August 16 revenue:
--       1. United States -> US (20 GB Plan): 19 orders, $697.26 revenue ($36.70 AOV)
--       2. United States -> US (10 GB Plan): 21 orders, $475.19 revenue ($22.63 AOV)
--       3. Canada -> CA (5 GB Plan):         23 orders, $405.67 revenue ($17.64 AOV)
--       4. Canada -> US (3 GB Plan):         42 orders, $348.93 revenue ($8.31 AOV)
--   - Quota Mix: Strong demand for premium 10 GB and 20 GB tiers lifted overall revenue realization.
-- ACTIONABLE RECOMMENDATION:
--   Bundle 10 GB and 20 GB tiers with pre-departure weekend marketing packages in North America.
-- ---------------------------------------------------------------------
SELECT 
    geo_country AS buyer_country,
    transaction_plan_destination AS destination,
    transaction_plan_quota AS quota_gb,
    COUNT(*) AS orders_count,
    ROUND(SUM(total_billings_in_usd), 2) AS revenue_usd,
    ROUND(SUM(total_billings_in_usd) / COUNT(*), 2) AS avg_price_usd
FROM `homework-data2020.saily_data_analyst.sessions`
WHERE session_date = '2024-08-16' 
  AND transaction_id IS NOT NULL
GROUP BY 1, 2, 3
ORDER BY revenue_usd DESC
LIMIT 10;


-- ---------------------------------------------------------------------
-- QUERY 6: GLOBAL TOP 10 REVENUE CORRIDORS (FULL 27-DAY LIFETIME)
-- ---------------------------------------------------------------------
-- BUSINESS OBJECTIVE:
--   Identify Saily's primary commercial corridors across the entire dataset, mapping
--   the Pareto distribution of revenue by origin-destination pairs.
-- TECHNICAL METHODOLOGY:
--   Group completed transactions by origin (`geo_country`) and destination (`transaction_plan_destination`),
--   calculating purchase count, total revenue, AOV, and percentage share of global revenue ($358,625.85).
-- EMPIRICAL FINDINGS:
--   - Top 1 Corridor: United States -> US (Domestic) generates $46,731.93 USD (3,572 orders, $13.08 AOV, 13.03% of global revenue).
--   - Top 2 Corridor: Canada -> US generates $27,915.52 USD (2,333 orders, $11.97 AOV, 7.78% of global revenue).
--   - Top 3 Corridor: Canada -> CA (Domestic) generates $23,423.08 USD (1,376 orders, $17.02 AOV, 6.53% of global revenue).
--   - Top 3 North American corridors alone account for 27.34% ($98,070.53 USD) of global revenue.
--   - High-Yield Transatlantic Routes: Canada -> Austria ($27.66 AOV) and US -> Austria ($24.16 AOV) command the highest basket sizes.
-- ACTIONABLE RECOMMENDATION:
--   Focus wholesale carrier procurement and roaming rate negotiations on US, CA, GB, TR, IT, and AT corridors.
-- ---------------------------------------------------------------------
SELECT 
    geo_country AS origin_country,
    transaction_plan_destination AS destination_country,
    COUNT(*) AS total_purchases,
    ROUND(SUM(total_billings_in_usd), 2) AS total_revenue_usd,
    ROUND(SUM(total_billings_in_usd) / COUNT(*), 2) AS average_order_value_usd,
    ROUND(SUM(total_billings_in_usd) * 100.0 / (
        SELECT SUM(total_billings_in_usd) 
        FROM `homework-data2020.saily_data_analyst.sessions` 
        WHERE transaction_id IS NOT NULL
    ), 2) AS pct_of_global_revenue
FROM `homework-data2020.saily_data_analyst.sessions`
WHERE transaction_id IS NOT NULL 
  AND transaction_plan_destination IS NOT NULL
GROUP BY 1, 2
ORDER BY total_revenue_usd DESC
LIMIT 10;


-- ---------------------------------------------------------------------
-- QUERY 7: SIMPSON'S PARADOX TEST - GEOGRAPHIC MIX VS HARDWARE PERFORMANCE
-- ---------------------------------------------------------------------
-- BUSINESS OBJECTIVE:
--   Test Hypothesis H6: Could the aggregate conversion deficit on Android be an illusion caused
--   by Simpson's Paradox (e.g., Android having a higher share of traffic in lower-converting emerging markets)?
-- TECHNICAL METHODOLOGY:
--   Calculate iOS vs Android Compatible conversion rate separately within each high-volume market (N >= 1,000 sessions).
--   Compare whether iOS maintains its conversion lead within individual markets.
-- EMPIRICAL FINDINGS:
--   - iOS outperforms Compatible Android across 10 out of 11 high-volume markets:
--       * Romania:        iOS 13.94% vs Android Compat 6.92%  (+7.02 pp iOS lead)
--       * Czechia:        iOS 17.06% vs Android Compat 10.85% (+6.21 pp iOS lead)
--       * Canada:         iOS 20.59% vs Android Compat 14.66% (+5.93 pp iOS lead)
--       * Sweden:         iOS 11.83% vs Android Compat 6.45%  (+5.38 pp iOS lead)
--       * Norway:         iOS 15.02% vs Android Compat 9.78%  (+5.24 pp iOS lead)
--       * Lithuania:      iOS 14.70% vs Android Compat 10.07% (+4.63 pp iOS lead)
--       * Poland:         iOS 11.11% vs Android Compat 6.79%  (+4.31 pp iOS lead)
--       * Ireland:        iOS 14.01% vs Android Compat 10.76% (+3.25 pp iOS lead)
--       * United States:  iOS 12.53% vs Android Compat 9.46%  (+3.07 pp iOS lead)
--       * United Kingdom: iOS 9.61%  vs Android Compat 8.25%  (+1.36 pp iOS lead)
--       * Morocco:        iOS 2.31%  vs Android Compat 4.83%  (-2.52 pp, distorted by Aug 27 iOS viral surge)
--   Conclusion: Simpson's Paradox is decisively REJECTED. The performance deficit is universal across markets.
-- ACTIONABLE RECOMMENDATION:
--   Direct product and engineering teams to focus on platform UX and promotional parity rather than geographic mix.
-- ---------------------------------------------------------------------
WITH market_cr AS (
    SELECT 
        geo_country,
        platform,
        COUNT(DISTINCT unique_session_id) AS sessions,
        COUNT(DISTINCT CASE WHEN transaction_id IS NOT NULL THEN unique_session_id END) AS purchases,
        COUNT(DISTINCT CASE WHEN transaction_id IS NOT NULL THEN unique_session_id END) * 100.0 / 
        COUNT(DISTINCT unique_session_id) AS cr
    FROM `homework-data2020.saily_data_analyst.sessions`
    WHERE platform = 'IOS' 
       OR (platform = 'ANDROID' AND esim_compatible = 'true')
    GROUP BY 1, 2
    HAVING sessions >= 1000
)
SELECT 
    geo_country,
    ROUND(MAX(CASE WHEN platform = 'IOS' THEN cr END), 2) AS ios_cr_pct,
    ROUND(MAX(CASE WHEN platform = 'ANDROID' THEN cr END), 2) AS android_compat_cr_pct,
    ROUND(
        MAX(CASE WHEN platform = 'IOS' THEN cr END) - MAX(CASE WHEN platform = 'ANDROID' THEN cr END), 
        2
    ) AS ios_lead_percentage_points,
    CASE 
        WHEN MAX(CASE WHEN platform = 'IOS' THEN cr END) > MAX(CASE WHEN platform = 'ANDROID' THEN cr END) 
        THEN 'iOS Outperforms'
        ELSE 'Android Compatible Outperforms'
    END AS regional_winner
FROM market_cr
GROUP BY 1
HAVING ios_cr_pct IS NOT NULL AND android_compat_cr_pct IS NOT NULL
ORDER BY ios_lead_percentage_points DESC;
