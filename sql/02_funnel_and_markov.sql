-- =====================================================================
-- SCRIPT: 02_FUNNEL_AND_MARKOV.SQL
-- PURPOSE: eCommerce Conversion Funnel, Statistical Inference & Stochastic Markov Transitions
-- AUTHOR: Mantas Normantas (mantas.normantas@gmail.com)
-- DATASET: homework-data2020.saily_data_analyst
-- =====================================================================


-- ---------------------------------------------------------------------
-- QUERY 1: COMPLETE 4-STAGE FUNNEL MATRIX ACROSS 3 DEVICE COHORTS
-- ---------------------------------------------------------------------
-- BUSINESS OBJECTIVE:
--   Reconstruct the full eCommerce conversion funnel across 4 discrete stages to pinpoint
--   precisely where user churn occurs across operating systems and hardware tiers.
-- TECHNICAL METHODOLOGY:
--   Join deduplicated session base with events flags (click_to_order_1, click_to_order_2)
--   and transaction status. Compute step-to-step conditional conversion and overall CR:
--     - Step 0 (S0): Session initiated
--     - Step 1 (S1): Plan / destination selected (`click_to_order_1`)
--     - Step 2 (S2): Checkout screen reached (`click_to_order_2`)
--     - Step 3 (Buy): Payment authorized (`transaction_id IS NOT NULL`)
-- EMPIRICAL FINDINGS:
--   - iOS Overall CR: 12.48% (S0->S1: 48.5%, S1->S2: 69.4%, S2->Buy: 37.1%)
--   - Android Compatible CR: 9.65% (S0->S1: 52.2%, S1->S2: 56.6%, S2->Buy: 32.7%)
--   - Android Incompatible CR: 0.41% (S0->S1: 29.1%, S1->S2: 60.0%, S2->Buy: 2.32%)
--   Crucial Insight: Android Compatible outperforms iOS at initial intent (S0->S1: 52.2% vs 48.5%),
--   but suffers severe drop-off between S1 and S2 (56.6% vs 69.4% on iOS; a -12.8 pp deficit),
--   indicating UX friction during plan configuration or checkout transition.
-- ACTIONABLE RECOMMENDATION:
--   Redesign the Android plan selection to checkout transition to eliminate the 12.8 pp S1->S2 gap.
-- ---------------------------------------------------------------------
WITH session_base AS (
    SELECT 
        unique_session_id,
        ANY_VALUE(platform) AS platform,
        ANY_VALUE(esim_compatible) AS esim_compatible,
        LOGICAL_OR(transaction_id IS NOT NULL) AS has_purchase
    FROM `homework-data2020.saily_data_analyst.sessions`
    GROUP BY unique_session_id
),
event_flags AS (
    SELECT 
        unique_session_id,
        MAX(CASE WHEN event_name = 'click_to_order_1' THEN 1 ELSE 0 END) AS has_order_1,
        MAX(CASE WHEN event_name = 'click_to_order_2' THEN 1 ELSE 0 END) AS has_order_2
    FROM `homework-data2020.saily_data_analyst.events`
    GROUP BY 1
),
funnel_aggregates AS (
    SELECT 
        s.platform,
        s.esim_compatible,
        COUNT(DISTINCT s.unique_session_id) AS step_0_sessions,
        COUNT(DISTINCT CASE WHEN e.has_order_1 = 1 THEN s.unique_session_id END) AS step_1_order_1,
        COUNT(DISTINCT CASE WHEN e.has_order_2 = 1 THEN s.unique_session_id END) AS step_2_order_2,
        COUNT(DISTINCT CASE WHEN s.has_purchase THEN s.unique_session_id END) AS step_3_purchase
    FROM session_base s
    LEFT JOIN event_flags e 
        ON s.unique_session_id = e.unique_session_id
    GROUP BY 1, 2
)
SELECT 
    platform,
    esim_compatible,
    step_0_sessions,
    step_1_order_1,
    ROUND(step_1_order_1 * 100.0 / NULLIF(step_0_sessions, 0), 2) AS step1_conv_pct,
    step_2_order_2,
    ROUND(step_2_order_2 * 100.0 / NULLIF(step_1_order_1, 0), 2) AS step2_conv_pct,
    step_3_purchase,
    ROUND(step_3_purchase * 100.0 / NULLIF(step_2_order_2, 0), 2) AS step3_conv_pct,
    ROUND(step_3_purchase * 100.0 / NULLIF(step_0_sessions, 0), 2) AS overall_cr_pct
FROM funnel_aggregates
ORDER BY platform, esim_compatible;


-- ---------------------------------------------------------------------
-- QUERY 2: TWO-PROPORTION Z-TEST (STATISTICAL INFERENCE & HYPOTHESIS TESTING)
-- ---------------------------------------------------------------------
-- BUSINESS OBJECTIVE:
--   Formally test whether the 2.84 percentage point conversion rate gap between iOS (12.48%)
--   and Android Compatible (9.65%) is statistically significant or merely random sampling variance.
-- TECHNICAL METHODOLOGY:
--   Compute pooled proportion p_pool = (x1 + x2) / (n1 + n2) and test statistic:
--     Z = (p1 - p2) / SQRT(p_pool * (1 - p_pool) * (1/n1 + 1/n2))
--   where:
--     x_ios = 16,088 conversions, n_ios = 128,872 sessions
--     x_and = 8,258 conversions,  n_and = 85,603 sessions
-- EMPIRICAL FINDINGS:
--   - Z-Score: 20.28 (Critical threshold for 99.9% confidence is Z = 3.29, p < 0.001)
--   - Conclusion: The null hypothesis is decisively rejected. The conversion gap is an authentic,
--     highly significant operational performance defect requiring dedicated engineering intervention.
-- ACTIONABLE RECOMMENDATION:
--   Present this Z-statistic to engineering leadership to substantiate prioritisation of Android sprint tasks.
-- ---------------------------------------------------------------------
WITH cohort_stats AS (
    SELECT 
        16088 AS x_ios, 128872 AS n_ios,
        8258 AS x_and,  85603 AS n_and
),
test_calculation AS (
    SELECT 
        x_ios * 1.0 / n_ios AS p_ios,
        x_and * 1.0 / n_and AS p_and,
        (x_ios + x_and) * 1.0 / (n_ios + n_and) AS p_pool,
        n_ios, n_and
    FROM cohort_stats
)
SELECT 
    ROUND(p_ios * 100, 2) AS ios_cr_pct,
    ROUND(p_and * 100, 2) AS compatible_android_cr_pct,
    ROUND((p_ios - p_and) * 100, 2) AS cr_diff_percentage_points,
    ROUND((p_ios - p_and) / SQRT(p_pool * (1 - p_pool) * (1.0/n_ios + 1.0/n_and)), 2) AS z_score_statistic,
    CASE 
        WHEN ABS((p_ios - p_and) / SQRT(p_pool * (1 - p_pool) * (1.0/n_ios + 1.0/n_and))) > 3.29 
        THEN 'Statistically Significant (p < 0.001, 99.9% Confidence)'
        ELSE 'Not Significant (Random Sample Noise)'
    END AS statistical_conclusion
FROM test_calculation;


-- ---------------------------------------------------------------------
-- QUERY 3: DAILY CONVERSION TIME-SERIES DYNAMICS ACROSS COHORTS
-- ---------------------------------------------------------------------
-- BUSINESS OBJECTIVE:
--   Track day-by-day conversion rate volatility across cohorts over the 27-day observation window,
--   detecting temporal shocks, regressions, and structural platform divergence.
-- TECHNICAL METHODOLOGY:
--   Aggregate sessions and transactions grouped by session_date, platform, and esim_compatible.
-- EMPIRICAL FINDINGS:
--   - iOS daily CR averages 12.0% - 14.8% across typical days, but crashes to 5.64% on August 27.
--   - Android Compatible CR remains consistently below iOS on every single date (ranging 8.5% - 10.98%).
--   - Android Incompatible remains consistently suppressed below 0.6% across the entire period (0.41% overall).
-- ACTIONABLE RECOMMENDATION:
--   Isolate August 27 and August 16 in Module 3 for root cause investigation.
-- ---------------------------------------------------------------------
SELECT 
    session_date,
    platform,
    esim_compatible,
    COUNT(DISTINCT unique_session_id) AS sessions,
    COUNT(DISTINCT CASE WHEN transaction_id IS NOT NULL THEN unique_session_id END) AS purchases,
    ROUND(
        COUNT(DISTINCT CASE WHEN transaction_id IS NOT NULL THEN unique_session_id END) * 100.0 / 
        NULLIF(COUNT(DISTINCT unique_session_id), 0), 
        2
    ) AS daily_cr_pct,
    ROUND(
        COUNT(DISTINCT CASE WHEN geo_country != 'Morocco' AND transaction_id IS NOT NULL THEN unique_session_id END) * 100.0 / 
        NULLIF(COUNT(DISTINCT CASE WHEN geo_country != 'Morocco' THEN unique_session_id END), 0), 
        2
    ) AS daily_ex_morocco_cr_pct
FROM `homework-data2020.saily_data_analyst.sessions`
GROUP BY 1, 2, 3
ORDER BY session_date, platform, esim_compatible;


-- ---------------------------------------------------------------------
-- QUERY 4: FINANCIAL OPPORTUNITY SIZING (COMMERCIAL UPSIDE OF ANDROID PARITY)
-- ---------------------------------------------------------------------
-- BUSINESS OBJECTIVE:
--   Quantify the top-line dollar value forfeited due to the Android hardware barrier and conversion deficit.
-- TECHNICAL METHODOLOGY:
--   Benchmark the 27,073 incompatible Android sessions against compatible Android conversion rates (9.65%)
--   and realized billings per converting session ($14.1615 USD), subtracting existing incompatible billings ($1,238.19 USD):
--     Potential Converting Sessions = ROUND(Incompatible Sessions * Compatible CR, 0) = 2,612
--     Gross Potential Revenue = 2,612 * $14.1615 = $36,989.84 USD ($36,985.44 unrounded)
--     Net Forfeited Revenue = $36,989.84 - $1,238.19 = $35,751.65 USD ($35,747.25 unrounded)
-- EMPIRICAL FINDINGS:
--   - Incompatible Android Sessions: 27,073 (existing converting sessions: 110, existing revenue: $1,238.19 USD)
--   - Compatible Android CR: 9.65% (8,258 / 85,603) | Compatible Android ARPPU: $14.16 USD ($116,945.46 / 8,258)
--   - Potential Compatible Converting Sessions (27-day): 2,612 (Net incremental: 2,502)
--   - Net Forfeited Revenue (27-day): $35,751.65 USD ($35,747.25 unrounded continuous)
--   - Annualized Upper-Bound Benchmark: ~$483,300 USD/year
-- ACTIONABLE RECOMMENDATION:
--   Incorporate this upper-bound opportunity sizing into the executive business case alongside Paid CAC Bleed.
-- ---------------------------------------------------------------------
WITH android_metrics AS (
    SELECT 
        esim_compatible,
        COUNT(DISTINCT unique_session_id) AS sessions,
        COUNT(DISTINCT CASE WHEN transaction_id IS NOT NULL THEN unique_session_id END) AS purchases,
        SUM(total_billings_in_usd) AS gross_revenue,
        COUNT(DISTINCT CASE WHEN transaction_id IS NOT NULL THEN unique_session_id END) * 1.0 / COUNT(DISTINCT unique_session_id) AS conversion_rate,
        SUM(total_billings_in_usd) / NULLIF(COUNT(DISTINCT CASE WHEN transaction_id IS NOT NULL THEN unique_session_id END), 0) AS revenue_per_converting_session
    FROM `homework-data2020.saily_data_analyst.sessions`
    WHERE platform = 'ANDROID'
    GROUP BY esim_compatible
)
SELECT 
    ROUND(compat.conversion_rate * 100, 2) AS compatible_android_cr_pct,
    ROUND(compat.revenue_per_converting_session, 2) AS compatible_android_arppu_usd,
    incompat.sessions AS incompatible_android_sessions,
    incompat.purchases AS existing_incompatible_purchases,
    ROUND(incompat.gross_revenue, 2) AS existing_incompatible_revenue_usd,
    ROUND(incompat.sessions * compat.conversion_rate, 0) AS potential_compatible_purchases,
    ROUND(incompat.sessions * compat.conversion_rate, 0) - incompat.purchases AS net_incremental_purchases,
    ROUND((ROUND(incompat.sessions * compat.conversion_rate, 0) * ROUND(compat.revenue_per_converting_session, 4)) - incompat.gross_revenue, 2) AS net_forfeited_revenue_usd,
    ROUND((incompat.sessions * compat.conversion_rate * compat.revenue_per_converting_session) - incompat.gross_revenue, 2) AS net_forfeited_revenue_unrounded_usd
FROM android_metrics compat
CROSS JOIN android_metrics incompat
WHERE compat.esim_compatible = 'true' 
  AND incompat.esim_compatible = 'false';


-- ---------------------------------------------------------------------
-- QUERY 5: STOCHASTIC MARKOV STATE TRANSITION PROBABILITY MATRIX ($P_{ij}$)
-- ---------------------------------------------------------------------
-- BUSINESS OBJECTIVE:
--   Model user progression through the eCommerce funnel as an absorbing Markov Chain, measuring
--   discrete stage transition probabilities P(S_i -> S_j) and the terminal checkout drop hazard rate.
-- TECHNICAL METHODOLOGY:
--   Define discrete states: S0 (Session), S1 (Order 1), S2 (Order 2), Buy (Purchase), Drop (Exit).
--   Compute empirical conditional transition probabilities:
--     P(S0 -> S1) = N(S1) / N(S0)
--     P(S1 -> S2) = N(S2) / N(S1)
--     P(S2 -> Buy) = N(Buy) / N(S2)
--     Drop Hazard Rate = 1 - P(S_i -> S_{i+1})
-- EMPIRICAL FINDINGS:
--   1. Android Incompatible Terminal Checkout Drop Hazard is 97.68% (P(S2 -> Buy) = 2.32%).
--      Users browse, configure plans, click to checkout, and then 98% hit a terminal wall.
--   2. Android Compatible exhibits an elevated S1 -> S2 Drop Hazard of 43.42% vs iOS 30.58%
--      (+12.84 pp higher abandonment before reaching checkout).
-- ACTIONABLE RECOMMENDATION:
--   Implement early hardware pre-qualification modals on Android to eliminate terminal checkout drop hazard.
-- ---------------------------------------------------------------------
WITH cohort_funnel AS (
    SELECT 
        s.unique_session_id,
        CASE 
            WHEN s.platform = 'IOS' THEN 'iOS'
            WHEN s.platform = 'ANDROID' AND s.esim_compatible = 'true' THEN 'Android Compatible'
            ELSE 'Android Incompatible'
        END AS cohort,
        MAX(CASE WHEN e.event_name = 'click_to_order_1' THEN 1 ELSE 0 END) AS has_s1,
        MAX(CASE WHEN e.event_name = 'click_to_order_2' THEN 1 ELSE 0 END) AS has_s2,
        MAX(CASE WHEN s.transaction_id IS NOT NULL THEN 1 ELSE 0 END) AS has_buy
    FROM `homework-data2020.saily_data_analyst.sessions` s
    LEFT JOIN `homework-data2020.saily_data_analyst.events` e 
        ON s.unique_session_id = e.unique_session_id
    GROUP BY 1, 2
),
cohort_totals AS (
    SELECT 
        cohort,
        COUNT(*) AS total_s0,
        COUNTIF(has_s1 = 1) AS total_s1,
        COUNTIF(has_s2 = 1) AS total_s2,
        COUNTIF(has_buy = 1) AS total_buy
    FROM cohort_funnel
    GROUP BY 1
)
SELECT 
    cohort,
    total_s0 AS sessions_n,
    -- Transition S0 -> S1 (Exploration to plan selection)
    ROUND(total_s1 * 1.0 / total_s0, 4) AS p_s0_to_s1,
    ROUND(1 - (total_s1 * 1.0 / total_s0), 4) AS p_s0_to_drop,
    -- Transition S1 -> S2 (Plan selection to checkout initiation)
    ROUND(total_s2 * 1.0 / total_s1, 4) AS p_s1_to_s2,
    ROUND(1 - (total_s2 * 1.0 / total_s1), 4) AS p_s1_to_drop,
    -- Transition S2 -> Buy (Checkout initiation to payment completion)
    ROUND(total_buy * 1.0 / total_s2, 4) AS p_s2_to_purchase,
    ROUND(1 - (total_buy * 1.0 / total_s2), 4) AS p_s2_to_drop_hazard,
    -- Cumulative End-to-End Conversion Probability
    ROUND(total_buy * 1.0 / total_s0, 4) AS cumulative_purchase_probability
FROM cohort_totals
ORDER BY cumulative_purchase_probability DESC;
