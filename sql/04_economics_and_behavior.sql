-- =====================================================================
-- SCRIPT: 04_ECONOMICS_AND_BEHAVIOR.SQL
-- PURPOSE: Unit Economics, Promotional Discount Simulation, Predictive Seasonality,
--          Marketing CAC Bleed & Behavioral Funnel Navigation Topology
-- AUTHOR: Mantas Normantas (mantas.normantas@gmail.com)
-- DATASET: homework-data2020.saily_data_analyst
-- =====================================================================


-- ---------------------------------------------------------------------
-- QUERY 1: INTENT VS REALITY - DATA QUOTA EXPLORATION TEST (HYPOTHESIS H5)
-- ---------------------------------------------------------------------
-- BUSINESS OBJECTIVE:
--   Test Hypothesis H5 (Price Elasticity Downsell): determine whether users compare multiple quota
--   tiers and down-trade to smaller plans (e.g., 1GB) at checkout due to price shock.
-- TECHNICAL METHODOLOGY:
--   Note: Because `events` lacks `event_timestamp`, chronological ordering of multiple quota views
--   within a session cannot be assumed. Instead, deduplicate `sessions` by `unique_session_id` and
--   evaluate `COUNT(DISTINCT plan_quota)`, `MIN(plan_quota)`, and `MAX(plan_quota)` per converting session.
-- EMPIRICAL FINDINGS:
--   - 92.16% of buyers (22,512 / 24,426) inspect only ONE single quota tier during their session and buy it.
--   - Among the 7.82% of buyers (1,909 sessions) who actively compare 2+ quota tiers, 63.4% (1,211; 4.96% of all buyers)
--     purchase the LARGEST tier they viewed, while only 35.0% (668; 2.73% of all buyers) choose the SMALLEST tier.
--   - In total, 97.12% of buyers (23,723 / 24,426) purchase the maximum quota tier they inspected.
--   - Conclusion: H5 is decisively REJECTED. Abandonment is binary; users do not systematically trade down.
-- ACTIONABLE RECOMMENDATION:
--   Implement dynamic checkout upsell prompts ("Add 2GB for just $3.00") to encourage single-tier browsers to upgrade.
-- ---------------------------------------------------------------------
WITH dedup_buyers AS (
    SELECT 
        unique_session_id,
        ANY_VALUE(platform) AS platform,
        MAX(CAST(transaction_plan_quota AS INT64)) AS purchased_gb
    FROM `homework-data2020.saily_data_analyst.sessions`
    WHERE transaction_id IS NOT NULL AND transaction_plan_quota IS NOT NULL
    GROUP BY unique_session_id
),
quota_exploration AS (
    SELECT 
        b.unique_session_id,
        b.platform,
        b.purchased_gb,
        COUNT(DISTINCT e.plan_quota) AS distinct_quotas_viewed,
        MIN(e.plan_quota) AS min_viewed_gb,
        MAX(e.plan_quota) AS max_viewed_gb
    FROM dedup_buyers b
    JOIN `homework-data2020.saily_data_analyst.events` e 
        ON b.unique_session_id = e.unique_session_id
    WHERE e.plan_quota IS NOT NULL
    GROUP BY 1, 2, 3
)
SELECT 
    CASE 
        WHEN distinct_quotas_viewed = 1 AND purchased_gb = max_viewed_gb THEN '1. Single Quota Viewed & Purchased (Decisive)'
        WHEN distinct_quotas_viewed > 1 AND purchased_gb = max_viewed_gb THEN '2. Multi-Quota Viewed -> Bought Largest'
        WHEN distinct_quotas_viewed > 1 AND purchased_gb = min_viewed_gb THEN '3. Multi-Quota Viewed -> Bought Smallest'
        WHEN distinct_quotas_viewed > 1 THEN '4. Multi-Quota Viewed -> Bought Middle Tier'
        ELSE '5. Other / Unmatched'
    END AS quota_choice_behavior,
    COUNT(*) AS converting_sessions,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_converting_sessions
FROM quota_exploration
GROUP BY 1
ORDER BY converting_sessions DESC;


-- ---------------------------------------------------------------------
-- QUERY 2: UNIT ECONOMICS - EFFECTIVE PRICE PER GB ACROSS CORE CORRIDORS
-- ---------------------------------------------------------------------
-- BUSINESS OBJECTIVE:
--   Evaluate Saily's pricing architecture and volume discounting curves across core travel
--   corridors (US, CA, TR, IT) across standard tier allocations (1GB, 3GB, 5GB, 10GB).
-- TECHNICAL METHODOLOGY:
--   Filter completed orders for top corridors and quota tiers, computing price dispersion
--   (MIN, MAX, AVG, STDDEV) and effective unit price ($/GB = AVG(price) / quota_gb).
-- EMPIRICAL FINDINGS:
--   - Steep volume discounting is evident: in the US corridor, price per GB falls from $3.66/GB (1GB plan)
--     down to $2.24/GB on the 10GB plan (-39% volume concession).
--   - Turkey (TR) offers the highest unit discount: $3.47/GB (1GB) down to $1.53/GB (10GB) (-56% discount).
--   - Intro promo pricing ($0.99 minimum) creates an aggressive customer acquisition hook across US and TR.
-- ACTIONABLE RECOMMENDATION:
--   Highlight the volume savings badge ("Save 40% per GB with 10GB") directly in catalog cards to steer volume.
-- ---------------------------------------------------------------------
WITH clean_orders AS (
    -- Filter transactions with valid quota and destination records in core target corridors
    SELECT 
        transaction_plan_destination AS destination,
        CAST(transaction_plan_quota AS INT64) AS quota_gb,
        platform,
        total_billings_in_usd
    FROM `homework-data2020.saily_data_analyst.sessions`
    WHERE transaction_id IS NOT NULL 
      AND transaction_plan_quota IS NOT NULL
      AND transaction_plan_destination IN ('US', 'CA', 'TR', 'IT')
      AND CAST(transaction_plan_quota AS INT64) IN (1, 3, 5, 10)
)
SELECT 
    destination,
    quota_gb,
    platform,
    COUNT(*) AS total_orders,
    -- Financial boundary and dispersion metrics
    ROUND(MIN(total_billings_in_usd), 2) AS min_price_usd,
    ROUND(MAX(total_billings_in_usd), 2) AS max_price_usd,
    ROUND(AVG(total_billings_in_usd), 2) AS avg_price_usd,
    ROUND(STDDEV(total_billings_in_usd), 2) AS price_stddev,
    -- Effective unit economics metric: realized dollar price per individual gigabyte
    ROUND(AVG(total_billings_in_usd) / quota_gb, 2) AS effective_price_per_gb
FROM clean_orders
GROUP BY destination, quota_gb, platform
ORDER BY destination, quota_gb, platform;


-- ---------------------------------------------------------------------
-- QUERY 3: PROMOTIONAL PENETRATION & DISCOUNT VOUCHER SEGMENTATION
-- ---------------------------------------------------------------------
-- BUSINESS OBJECTIVE:
--   Quantify promotional voucher and discount adoption between iOS and Android, determining whether
--   unequal promotional access explains part of the Android conversion gap.
-- TECHNICAL METHODOLOGY:
--   Establish catalog list price benchmarks per destination and quota tier using MAX(total_billings_in_usd).
--   Segment orders into: Full Catalog Price, Discounted/Referral Voucher, and Intro Promo ($0.99 Tier).
-- EMPIRICAL FINDINGS:
--   - iOS exhibits 25.50% promotional penetration (24.10% voucher discount + 1.40% intro promo).
--   - Android exhibits only 21.07% promotional penetration (20.14% voucher discount + 0.93% intro promo).
--   - Android users face Full Catalog Price in 78.93% of orders vs 74.50% on iOS (+4.43 pp voucher deficit).
--   - Android users are more price-sensitive, yet receive fewer voucher discounts than iOS users.
-- ACTIONABLE RECOMMENDATION:
--   Implement targeted Android introductory vouchers ($3.00 off first plan) to eliminate this promotional disparity.
-- ---------------------------------------------------------------------
WITH catalog_benchmarks AS (
    -- Derive baseline catalog list prices by identifying maximum realized billing per destination and quota
    SELECT 
        transaction_plan_destination AS destination,
        CAST(transaction_plan_quota AS INT64) AS quota_gb,
        MAX(total_billings_in_usd) AS list_price_usd
    FROM `homework-data2020.saily_data_analyst.sessions`
    WHERE transaction_id IS NOT NULL 
      AND transaction_plan_quota IS NOT NULL
    GROUP BY 1, 2
),
order_discounts AS (
    -- Compare each transaction's billed price against the derived catalog list price
    SELECT 
        s.unique_session_id,
        s.platform,
        s.transaction_plan_destination AS destination,
        CAST(s.transaction_plan_quota AS INT64) AS quota_gb,
        s.total_billings_in_usd AS billed_price,
        b.list_price_usd,
        (b.list_price_usd - s.total_billings_in_usd) AS discount_amount_usd,
        -- Classify pricing tier based on price relative to catalog list price
        CASE 
            WHEN s.total_billings_in_usd <= 1.00 THEN 'Intro Promo ($0.99 Tier)'
            WHEN s.total_billings_in_usd < b.list_price_usd THEN 'Discounted / Referral Voucher'
            ELSE 'Full Catalog Price'
        END AS pricing_tier
    FROM `homework-data2020.saily_data_analyst.sessions` s
    JOIN catalog_benchmarks b 
        ON s.transaction_plan_destination = b.destination 
       AND CAST(s.transaction_plan_quota AS INT64) = b.quota_gb
    WHERE s.transaction_id IS NOT NULL
)
SELECT 
    platform,
    pricing_tier,
    COUNT(*) AS total_orders,
    -- Compute percentage of orders within each operating system
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY platform), 2) AS pct_of_platform_orders,
    ROUND(AVG(billed_price), 2) AS avg_realized_price_usd,
    ROUND(AVG(discount_amount_usd), 2) AS avg_discount_usd
FROM order_discounts
GROUP BY 1, 2
ORDER BY platform, total_orders DESC;


-- ---------------------------------------------------------------------
-- QUERY 4: TOTAL DOLLAR DISCOUNT POOL CONCEDED ACROSS TRANSACTIONS
-- ---------------------------------------------------------------------
-- BUSINESS OBJECTIVE:
--   Quantify the total dollar revenue conceded in price promotions and referral vouchers across
--   all transactions over the 27-day observation period, benchmarking promotional capital allocation.
-- TECHNICAL METHODOLOGY:
--   Compare realized revenue against theoretical gross list revenue per order:
--     Discount Conceded = GREATEST(0, list_price_usd - billed_revenue)
--   Aggregate total realized billings, gross list value, and effective discount rate.
-- EMPIRICAL FINDINGS:
--   - Saily conceded a total of $31,237.12 USD in price reductions (8.01% effective global discount rate).
--   - iOS absorbed $21,385.43 USD in discounts ($1.29 average discount per order).
--   - Android absorbed $9,851.69 USD in discounts ($1.14 average discount per order).
--   - iOS orders receive +13.2% larger dollar subsidies per order than Android orders.
-- ACTIONABLE RECOMMENDATION:
--   Rebalance the discount budget: reallocate ~$5,000 USD from saturated iOS cohorts to Android onboarding.
-- ---------------------------------------------------------------------
WITH catalog_benchmarks AS (
    -- Extract maximum list price per destination and quota tier
    SELECT 
        transaction_plan_destination AS destination,
        CAST(transaction_plan_quota AS INT64) AS quota_gb,
        MAX(total_billings_in_usd) AS list_price_usd
    FROM `homework-data2020.saily_data_analyst.sessions`
    WHERE transaction_id IS NOT NULL 
      AND transaction_plan_quota IS NOT NULL
    GROUP BY 1, 2
),
order_discounts AS (
    -- Calculate gross price concession per transaction
    SELECT 
        s.platform,
        s.total_billings_in_usd AS billed_revenue,
        b.list_price_usd,
        -- Ensure non-negative discount concessions
        GREATEST(0, b.list_price_usd - s.total_billings_in_usd) AS discount_given
    FROM `homework-data2020.saily_data_analyst.sessions` s
    JOIN catalog_benchmarks b 
        ON s.transaction_plan_destination = b.destination 
       AND CAST(s.transaction_plan_quota AS INT64) = b.quota_gb
    WHERE s.transaction_id IS NOT NULL
)
SELECT 
    platform,
    COUNT(*) AS total_orders,
    ROUND(SUM(billed_revenue), 2) AS realized_revenue_usd,
    ROUND(SUM(list_price_usd), 2) AS theoretical_gross_list_revenue_usd,
    ROUND(SUM(discount_given), 2) AS total_discounts_conceded_usd,
    -- Effective promotional markdown rate against theoretical catalog gross value
    ROUND(SUM(discount_given) * 100.0 / SUM(list_price_usd), 2) AS discount_rate_pct,
    -- Average dollar concession per completed order
    ROUND(AVG(discount_given), 2) AS avg_discount_per_order_usd
FROM order_discounts
GROUP BY 1;


-- ---------------------------------------------------------------------
-- QUERY 5: "LEVEL THE PLAYING FIELD" - ANDROID PROMO PARITY P&L SIMULATION
-- ---------------------------------------------------------------------
-- BUSINESS OBJECTIVE:
--   Simulate the financial P&L impact of closing the Android promotional discount gap to match iOS.
--   Determine whether subsidizing price-sensitive Android users yields net incremental revenue or margin loss.
-- TECHNICAL METHODOLOGY:
--   Establish compatible Android baseline metrics (85,603 sessions, 9.65% CR, $14.16 AOV).
--   Model Conservative (+0.60 pp CR uplift, -$0.50 AOV subsidy) and Optimistic (+1.20 pp CR uplift, -$0.50 AOV)
--   scenarios to calculate incremental net cash flows over 27 days and annualized run-rates.
-- EMPIRICAL FINDINGS:
--   - Conservative uplift (+0.60 pp CR) generates +514 net converting sessions and **+$2,887.78 USD net gain** over 27 days.
--   - Optimistic uplift (+1.20 pp CR) generates +1,027 net converting sessions and **+$9,904.56 USD net gain** over 27 days.
--   - Annualized net revenue expansion ranges from **+$39,000 to +$134,000 USD/year**.
--   - Conclusion: Under both parametric sensitivity scenarios, incremental conversion volume outweighs the -$0.50 subsidy.
-- ACTIONABLE RECOMMENDATION:
--   Run a controlled A/B experiment testing an automated Android Welcome Discount ($3 off first order) at plan selection.
-- ---------------------------------------------------------------------
WITH baseline_stats AS (
    -- Calculate baseline conversion rate, converting session volume, and ARPPU for compatible Android devices
    SELECT 
        COUNT(DISTINCT unique_session_id) AS compatible_sessions,
        COUNT(DISTINCT CASE WHEN transaction_id IS NOT NULL THEN unique_session_id END) AS current_purchases,
        SUM(total_billings_in_usd) AS current_revenue,
        COUNT(DISTINCT CASE WHEN transaction_id IS NOT NULL THEN unique_session_id END) * 1.0 / 
        COUNT(DISTINCT unique_session_id) AS current_cr,
        SUM(total_billings_in_usd) / 
        COUNT(DISTINCT CASE WHEN transaction_id IS NOT NULL THEN unique_session_id END) AS current_aov
    FROM `homework-data2020.saily_data_analyst.sessions`
    WHERE platform = 'ANDROID' AND esim_compatible = 'true'
)
SELECT 
    compatible_sessions,
    current_purchases,
    ROUND(current_cr * 100, 2) AS current_cr_pct,
    ROUND(current_aov, 2) AS current_arppu_usd,
    ROUND(current_revenue, 2) AS current_revenue_usd,
    -- Scenario 1: Conservative conversion uplift (+0.60 pp CR, $0.50 discount subsidy)
    ROUND(compatible_sessions * (current_cr + 0.0060), 0) AS simulated_purchases_conservative,
    ROUND(compatible_sessions * (current_cr + 0.0060) * (current_aov - 0.50), 2) AS simulated_revenue_conservative,
    ROUND((compatible_sessions * (current_cr + 0.0060) * (current_aov - 0.50)) - current_revenue, 2) AS net_gain_conservative_usd,
    -- Scenario 2: Optimistic conversion uplift (+1.20 pp CR, $0.50 discount subsidy)
    ROUND(compatible_sessions * (current_cr + 0.0120), 0) AS simulated_purchases_optimistic,
    ROUND(compatible_sessions * (current_cr + 0.0120) * (current_aov - 0.50), 2) AS simulated_revenue_optimistic,
    ROUND((compatible_sessions * (current_cr + 0.0120) * (current_aov - 0.50)) - current_revenue, 2) AS net_gain_optimistic_usd
FROM baseline_stats;


-- ---------------------------------------------------------------------
-- QUERY 6: MARKETING CAC BLEED & HARDWARE GATE FILTERING P&L
-- ---------------------------------------------------------------------
-- BUSINESS OBJECTIVE:
--   Quantify the financial penalty of acquiring incompatible Android traffic through paid performance
--   marketing channels, proving the business case for device-level targeting exclusion filters.
-- TECHNICAL METHODOLOGY:
--   Aggregate total incompatible Android sessions (27,073) and realized gross revenue ($1,238.19 USD).
--   Cross join across simulated acquisition cost tiers ($0.75, $1.50, $2.50, $3.50 CAC per install/session)
--   to compute net ad spend losses: Net Loss = Current Revenue - (Sessions * CAC).
-- EMPIRICAL FINDINGS:
--   - At benchmark $1.50 blended CAC: $40,609.50 USD in ad spend is wasted acquiring incompatible users.
--   - Net marketing loss at $1.50 CAC: **-$39,371.31 USD every 27 days** (-$532,240 USD/year annualized bleed).
--   - At high-tier $2.50 CAC: Net marketing loss expands to **-$66,444.31 USD** (-$898,230 USD/year annualized bleed).
-- ACTIONABLE RECOMMENDATION:
--   Enforce hardware exclusion lists in Google/Meta Ads AND enable Google Play Console Device Catalog gating
--   (`android.hardware.telephony.euicc`) so Google UAC automatically blocks installs on non-eSIM handsets.
-- ---------------------------------------------------------------------
WITH incompatible_volume AS (
    -- Extract total incompatible Android session volume and realized billings
    SELECT 
        COUNT(DISTINCT unique_session_id) AS total_incompatible_sessions,
        COUNT(DISTINCT CASE WHEN transaction_id IS NOT NULL THEN unique_session_id END) AS current_purchases,
        ROUND(SUM(total_billings_in_usd), 2) AS current_gross_revenue
    FROM `homework-data2020.saily_data_analyst.sessions`
    WHERE platform = 'ANDROID' AND esim_compatible = 'false'
)
SELECT 
    cac_tier.simulated_cac_usd,
    inv.total_incompatible_sessions,
    -- Estimated acquisition expenditure wasted on incompatible hardware
    ROUND(inv.total_incompatible_sessions * cac_tier.simulated_cac_usd, 2) AS estimated_acquisition_spend_wasted,
    inv.current_purchases,
    inv.current_gross_revenue,
    -- Net P&L bleed after subtracting realized gross receipts
    ROUND(inv.current_gross_revenue - (inv.total_incompatible_sessions * cac_tier.simulated_cac_usd), 2) AS net_acquisition_loss_usd
FROM incompatible_volume inv
CROSS JOIN (
    -- Sensitivity range of customer acquisition costs per session / install
    SELECT 0.75 AS simulated_cac_usd UNION ALL
    SELECT 1.50 UNION ALL
    SELECT 2.50 UNION ALL
    SELECT 3.50
) cac_tier
ORDER BY simulated_cac_usd;


-- ---------------------------------------------------------------------
-- QUERY 7: PREDICTIVE DAY-OF-WEEK DEMAND SEASONALITY MULTIPLIERS
-- ---------------------------------------------------------------------
-- BUSINESS OBJECTIVE:
--   Quantify weekly cyclicality and travel departure patterns to guide marketing bid scheduling,
--   promotional cadence, and capacity forecasting across calendar days.
-- TECHNICAL METHODOLOGY:
--   Extract day-of-week name and index from `session_date`, aggregate daily average sessions,
--   purchases, revenue, and conversion rate. Compute Seasonality Index normalized against the daily mean:
--     Seasonality Index = Day Purchases / Average Daily Purchases
-- EMPIRICAL FINDINGS:
--   - Distinct Weekend Flight Factor: Friday (1.083 index, 978.0 converting sessions/day, 11.10% CR) and Saturday
--     (1.074 index, 969.8 converting sessions/day, 10.89% CR) drive peak demand, with daily revenue exceeding $14,119 USD.
--   - Mid-week trough: Wednesday exhibits the lowest demand (0.922 index, 833.0 converting sessions/day, 9.52% CR).
--   - Note on Tuesday: Tuesday average sessions (10,355.5/day across 4 Tuesdays = 41,422 sessions) and CR (8.29%)
--     are skewed by the August 27 Morocco viral spike (15,281 sessions). Across the 3 normal Tuesdays (Aug 6, 13, 20),
--     sessions averaged 8,713.7/day (26,141 total) and conversion averaged 9.71% (845.7 / 8,713.7).
--   - Note on Daily Distinct Grain: Summing daily distinct sessions across all 27 calendar dates yields 249,678
--     daily session-date instances vs 241,548 globally distinct `unique_session_id`s, indicating 8,130 sessions
--     spanned UTC midnight across consecutive calendar dates.
-- ACTIONABLE RECOMMENDATION:
--   Surge performance marketing bids by +15% to +20% on Thursday evening through Saturday afternoon.
-- ---------------------------------------------------------------------
WITH daily_traffic AS (
    -- Aggregate traffic and revenue at the calendar date grain
    SELECT 
        session_date,
        FORMAT_DATE('%A', session_date) AS day_of_week,
        EXTRACT(DAYOFWEEK FROM session_date) AS dow_num,
        COUNT(DISTINCT unique_session_id) AS sessions,
        COUNT(DISTINCT CASE WHEN transaction_id IS NOT NULL THEN unique_session_id END) AS purchases,
        SUM(total_billings_in_usd) AS revenue_usd
    FROM `homework-data2020.saily_data_analyst.sessions`
    GROUP BY 1, 2, 3
),
dow_summary AS (
    -- Average daily metrics across repeating days of the week
    SELECT 
        day_of_week,
        dow_num,
        COUNT(*) AS occurrences,
        ROUND(AVG(sessions), 1) AS avg_daily_sessions,
        ROUND(AVG(purchases), 1) AS avg_daily_purchases,
        ROUND(AVG(revenue_usd), 2) AS avg_daily_revenue_usd,
        ROUND(SUM(purchases) * 100.0 / SUM(sessions), 2) AS avg_cr_pct
    FROM daily_traffic
    GROUP BY 1, 2
)
SELECT 
    day_of_week,
    avg_daily_sessions,
    avg_daily_purchases,
    avg_daily_revenue_usd,
    avg_cr_pct,
    -- Demand seasonality multiplier relative to global daily purchase average
    ROUND(avg_daily_purchases / (SELECT AVG(avg_daily_purchases) FROM dow_summary), 3) AS demand_seasonality_index
FROM dow_summary
ORDER BY dow_num;


-- ---------------------------------------------------------------------
-- QUERY 8: BUYER ARCHETYPE SEGMENTATION - IN-DESTINATION VS TRANSATLANTIC
-- ---------------------------------------------------------------------
-- BUSINESS OBJECTIVE:
--   Classify purchasing customers into behavioral buyer archetypes based on origin-destination
--   geography to uncover overlooked commercial segments and high-yield traveler profiles.
-- TECHNICAL METHODOLOGY:
--   Categorize each transaction into four archetypes:
--     1. In-Destination Purchase (On-Arrival Traveler / Local Backup SIM): user IP country equals destination country (US->US, CA->CA, GB->GB, LT->LT)
--     2. Long-Haul Transatlantic Explorer: North American origin purchasing European destinations
--     3. Accidental Domestic (Morocco): Moroccan origin purchasing Moroccan local data
--     4. Regional Cross-Border Travel: All other international cross-border combinations
-- EMPIRICAL FINDINGS:
--   - In-Destination Purchases represent **22.89% of total global revenue ($82,100.94 USD)** and 23.63% of orders (5,939 orders).
--     This captures two high-intent segments: (a) international travelers purchasing eSIMs upon arrival (e.g., on airport Wi-Fi)
--     and (b) domestic residents utilizing Saily as a secondary/backup data SIM.
--   - Long-Haul Transatlantic Explorers command the highest basket size: **$17.28 AOV and 9.5 GB average quota**.
--   - Regional Cross-Border Travel drives 62.03% of total revenue ($222,439.80 USD).
-- ACTIONABLE RECOMMENDATION:
--   Tailor app onboarding for same-country IP sessions: surface an "Already Landed? Instant Airport Activation"
--   and "Local Secondary Backup Data SIM" quick-select card.
-- ---------------------------------------------------------------------
WITH user_trips AS (
    -- Classify completed transactions into strategic buyer archetypes
    SELECT 
        unique_session_id,
        platform,
        geo_country AS origin,
        transaction_plan_destination AS destination,
        CAST(transaction_plan_quota AS INT64) AS quota_gb,
        total_billings_in_usd AS revenue,
        CASE 
            -- Archetype 1: In-Destination purchase (On-Arrival Traveler on local Wi-Fi or Domestic Backup SIM)
            WHEN (geo_country = 'United States' AND transaction_plan_destination = 'US')
              OR (geo_country = 'Canada' AND transaction_plan_destination = 'CA')
              OR (geo_country = 'United Kingdom' AND transaction_plan_destination = 'GB')
              OR (geo_country = 'Lithuania' AND transaction_plan_destination = 'LT')
            THEN 'In-Destination Purchase (On-Arrival Traveler / Local Backup SIM)'
            -- Archetype 2: High-yield transatlantic vacationers traveling North America to Europe
            WHEN geo_country IN ('United States', 'Canada') 
             AND transaction_plan_destination IN ('IT', 'AT', 'FR', 'ES', 'DE', 'GB', 'GR') 
            THEN 'Long-Haul Transatlantic Explorer'
            -- Archetype 3: Viral domestic traffic in emerging market (non-converting price shock segment)
            WHEN geo_country = 'Morocco' AND transaction_plan_destination = 'MA' 
            THEN 'Accidental Domestic (Morocco)'
            -- Archetype 4: Standard cross-border international travel
            ELSE 'Regional Cross-Border Travel'
        END AS archetype
    FROM `homework-data2020.saily_data_analyst.sessions`
    WHERE transaction_id IS NOT NULL
)
SELECT 
    archetype,
    COUNT(*) AS total_orders,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct_of_orders,
    ROUND(SUM(revenue), 2) AS total_revenue_usd,
    ROUND(SUM(revenue) * 100.0 / SUM(SUM(revenue)) OVER(), 2) AS pct_of_revenue,
    ROUND(AVG(revenue), 2) AS aov_usd,
    ROUND(AVG(quota_gb), 1) AS avg_quota_gb
FROM user_trips
GROUP BY 1
ORDER BY total_revenue_usd DESC;


-- ---------------------------------------------------------------------
-- QUERY 9: SEARCH FATIGUE - CONVERSION RATE BY EVENT INTENSITY (DEDUPLICATED)
-- ---------------------------------------------------------------------
-- BUSINESS OBJECTIVE:
--   Determine the relationship between session event depth and conversion rate, isolating the
--   "Golden Engagement Window" versus the point where cognitive search fatigue sets in.
-- TECHNICAL METHODOLOGY:
--   First deduplicate `sessions` by `unique_session_id` (to avoid double-counting converting sessions
--   that emit both a NULL and non-NULL transaction row), then left join `events` and bucket into five depth tiers:
--   0 Events (Bounced), 1 Event (Single Interaction), 2-3 Events (Focused Intent / Golden Window),
--   4-6 Events (Comparative Browsing), and 7+ Events (Search Fatigue / Maze).
-- EMPIRICAL FINDINGS:
--   - 92.57% of all converting sessions (22,638 of 24,456) occur within the 2-3 Event window (30.37% CR).
--   - Once users enter comparative browsing (4-6 events), conversion drops by 49.1% down to 15.46%.
--   - At 7+ events (Search Fatigue), conversion collapses by 80.5% down to 5.91% (129 / 2,184 sessions).
-- ACTIONABLE RECOMMENDATION:
--   Streamline catalog filtering; recommend the #1 most popular plan immediately upon country selection.
-- ---------------------------------------------------------------------
WITH dedup_sessions AS (
    SELECT 
        unique_session_id,
        ANY_VALUE(platform) AS platform,
        LOGICAL_OR(transaction_id IS NOT NULL) AS has_purchased
    FROM `homework-data2020.saily_data_analyst.sessions`
    GROUP BY unique_session_id
),
session_events AS (
    -- Count total event actions recorded per unique session
    SELECT 
        s.unique_session_id,
        s.platform,
        s.has_purchased,
        COUNT(e.event_name) AS total_events_in_session
    FROM dedup_sessions s
    LEFT JOIN `homework-data2020.saily_data_analyst.events` e 
        ON s.unique_session_id = e.unique_session_id
    GROUP BY 1, 2, 3
),
bucketed_sessions AS (
    -- Classify session intensity into discrete behavioral engagement tiers
    SELECT 
        platform,
        has_purchased,
        CASE 
            WHEN total_events_in_session = 0 THEN '0 Events (Bounced)'
            WHEN total_events_in_session = 1 THEN '1 Event (Ultra Fast)'
            WHEN total_events_in_session BETWEEN 2 AND 3 THEN '2-3 Events (Focused Intent)'
            WHEN total_events_in_session BETWEEN 4 AND 6 THEN '4-6 Events (Comparative Browsing)'
            ELSE '7+ Events (Search Fatigue / Maze)'
        END AS browsing_depth_tier,
        -- Ordinal sorting rank
        CASE 
            WHEN total_events_in_session = 0 THEN 0
            WHEN total_events_in_session = 1 THEN 1
            WHEN total_events_in_session BETWEEN 2 AND 3 THEN 2
            WHEN total_events_in_session BETWEEN 4 AND 6 THEN 3
            ELSE 4
        END AS tier_rank
    FROM session_events
)
SELECT 
    browsing_depth_tier,
    COUNT(*) AS total_sessions,
    COUNTIF(has_purchased) AS total_purchases,
    -- Session conversion rate within engagement tier
    ROUND(COUNTIF(has_purchased) * 100.0 / COUNT(*), 2) AS conversion_rate_pct,
    -- Percentage distribution across all 241,548 unique sessions
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct_of_all_sessions
FROM bucketed_sessions
GROUP BY 1, tier_rank
ORDER BY tier_rank;


-- ---------------------------------------------------------------------
-- QUERY 10: DESTINATION INDECISION - SINGLE-COUNTRY VS MULTI-COUNTRY BROWSING (DEDUPLICATED)
-- ---------------------------------------------------------------------
-- BUSINESS OBJECTIVE:
--   Analyze whether users exploring multiple destination countries within a single session convert
--   or suffer from analysis paralysis due to lack of multi-country regional packages.
-- TECHNICAL METHODOLOGY:
--   Deduplicate `sessions` by `unique_session_id`, join `events`, and count distinct `plan_destination`
--   values viewed per session across all 115,995 engaged sessions.
-- EMPIRICAL FINDINGS:
--   - Single destination focus converts at 24.11% (21,970 converting sessions / 91,117 engaged sessions).
--   - Viewing 2 countries cuts conversion in half down to 12.12% (1,770 / 14,603; -49.7% relative drop).
--   - Viewing 3+ countries collapses conversion down to 6.69% (687 / 10,275; -72.3% relative drop).
--   - Exactly 24,878 engaged sessions (21.45%) explore multiple countries, representing uncaptured regional demand.
-- ACTIONABLE RECOMMENDATION:
--   Surface unified Regional Passes (e.g., "Europe Regional Pass") when 2+ countries are searched in one session.
-- ---------------------------------------------------------------------
WITH dedup_sessions AS (
    SELECT 
        unique_session_id,
        ANY_VALUE(platform) AS platform,
        LOGICAL_OR(transaction_id IS NOT NULL) AS has_purchased
    FROM `homework-data2020.saily_data_analyst.sessions`
    GROUP BY unique_session_id
),
destination_intent AS (
    -- Count distinct destination countries browsed within deduplicated engaged sessions
    SELECT 
        s.unique_session_id,
        s.platform,
        s.has_purchased,
        COUNT(DISTINCT e.plan_destination) AS distinct_destinations_viewed
    FROM dedup_sessions s
    JOIN `homework-data2020.saily_data_analyst.events` e 
        ON s.unique_session_id = e.unique_session_id
    WHERE e.plan_destination IS NOT NULL
    GROUP BY 1, 2, 3
)
SELECT 
    CASE 
        WHEN distinct_destinations_viewed = 1 THEN 'Single Destination Focus (1 Country)'
        WHEN distinct_destinations_viewed = 2 THEN 'Multi-Destination (2 Countries)'
        ELSE 'Indecision Loop (3+ Countries)'
    END AS destination_behavior,
    COUNT(*) AS engaged_sessions,
    COUNTIF(has_purchased) AS purchases,
    -- Conversion rate across destination exploration tiers
    ROUND(COUNTIF(has_purchased) * 100.0 / COUNT(*), 2) AS conversion_rate_pct,
    -- Share of total 115,995 engaged sessions
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct_of_engaged_sessions
FROM destination_intent
GROUP BY 1
ORDER BY engaged_sessions DESC;


-- ---------------------------------------------------------------------
-- QUERY 11: DESTINATION CROSS-SHOPPING - REGIONAL VS SINGLE-COUNTRY COMPARISON
-- ---------------------------------------------------------------------
-- BUSINESS OBJECTIVE:
--   Identify cross-shopping behavior where converting users inspect an alternative destination in `events`
--   alongside their final purchased destination (`transaction_plan_destination`).
-- TECHNICAL METHODOLOGY:
--   Because `events` lacks `event_timestamp`, multi-destination sessions represent within-session
--   cross-shopping rather than a timestamped sequence. Filter directly for `e.plan_destination != s.transaction_plan_destination`
--   and deduplicate by `(unique_session_id, alt_destination, purchased_destination)` so no cross-shopped
--   destination is dropped by arbitrary row-number tie-breaking.
-- EMPIRICAL FINDINGS:
--   - Out of 24,456 unique converting sessions, 21,349 (87.29%) viewed exclusively their purchased destination,
--     3,078 (12.59%) cross-shopped at least one alternative destination in the same session, and 29 (0.12%) had 0 events.
--   - The #1 cross-shopped pair is Europe regional ('EU') alongside Austria ('AT'), accounting for 693 converting sessions (22.51%).
--   - Users actively compare broad regional/global passes ('EU', 'GLB', 'ASA', 'NAM') against single-country plans ('AT', 'GB', 'AE', 'AU', 'CA', 'US').
-- ACTIONABLE RECOMMENDATION:
--   Provide clear side-by-side $/GB and coverage comparisons between Country Plans and Regional Passes.
-- ---------------------------------------------------------------------
WITH cross_shop_pairs AS (
    SELECT DISTINCT
        s.unique_session_id,
        e.plan_destination AS alternative_browsed_destination,
        s.transaction_plan_destination AS purchased_destination
    FROM `homework-data2020.saily_data_analyst.sessions` s
    JOIN `homework-data2020.saily_data_analyst.events` e 
        ON s.unique_session_id = e.unique_session_id
    WHERE s.transaction_id IS NOT NULL 
      AND e.plan_destination IS NOT NULL
      AND e.plan_destination != s.transaction_plan_destination
)
SELECT 
    alternative_browsed_destination,
    purchased_destination,
    COUNT(DISTINCT unique_session_id) AS cross_shopped_sessions_count,
    ROUND(COUNT(DISTINCT unique_session_id) * 100.0 / (
        SELECT COUNT(DISTINCT unique_session_id) FROM cross_shop_pairs
    ), 2) AS pct_of_cross_shopped_sessions
FROM cross_shop_pairs
GROUP BY 1, 2
ORDER BY cross_shopped_sessions_count DESC
LIMIT 10;


-- ---------------------------------------------------------------------
-- QUERY 12: PAYMENT RETRIES & PSP CHECKOUT FRICTION TOPOLOGY (DEDUPLICATED)
-- ---------------------------------------------------------------------
-- BUSINESS OBJECTIVE:
--   Measure checkout friction and payment retries by counting `click_to_order_2` attempts per unique session.
--   Detect loop failures on incompatible devices and checkout abandonment across payment gateways.
-- TECHNICAL METHODOLOGY:
--   Deduplicate `sessions` by `unique_session_id` first (preventing duplicate session rows from multiplying
--   event counts), then count occurrences of `click_to_order_2` per session across the exact Step 2 cohorts
--   (4,735 Android Incompatible, 25,273 Android Compatible, 43,411 iOS).
-- EMPIRICAL FINDINGS:
--   - 658 incompatible Android sessions (13.9% of the 4,735 reaching checkout) attempted checkout 2+ times
--     (504 twice, 154 3+ times), looping through failed checkout attempts.
--   - Across compatible devices, 6,434 sessions (2,281 Android Compatible + 4,153 iOS) required 2+ checkout clicks.
--   - On iOS, sessions requiring 3+ checkout attempts suffer a 52.2% drop in checkout conversion (37.47% -> 17.92%).
-- ACTIONABLE RECOMMENDATION:
--   Block checkout attempts on incompatible devices at app entry; ingest automated PSP decline telemetry.
-- ---------------------------------------------------------------------
WITH dedup_sessions AS (
    SELECT 
        unique_session_id,
        ANY_VALUE(platform) AS platform,
        ANY_VALUE(esim_compatible) AS esim_compatible,
        LOGICAL_OR(transaction_id IS NOT NULL) AS has_purchased
    FROM `homework-data2020.saily_data_analyst.sessions`
    GROUP BY unique_session_id
),
order_2_frequency AS (
    -- Count checkout click attempts (`click_to_order_2`) per unique session
    SELECT 
        s.unique_session_id,
        s.platform,
        s.esim_compatible,
        s.has_purchased,
        COUNTIF(e.event_name = 'click_to_order_2') AS checkout_attempts
    FROM dedup_sessions s
    JOIN `homework-data2020.saily_data_analyst.events` e 
        ON s.unique_session_id = e.unique_session_id
    GROUP BY 1, 2, 3, 4
    HAVING checkout_attempts > 0  -- Filter only sessions reaching Step 2 (checkout stage)
)
SELECT 
    platform,
    esim_compatible,
    -- Categorize checkout intensity based on payment button click attempts
    CASE 
        WHEN checkout_attempts = 1 THEN '1 Attempt (Standard Flow)'
        WHEN checkout_attempts = 2 THEN '2 Attempts (Retry / Card Issue)'
        ELSE '3+ Attempts (Severe Payment Failure)'
    END AS checkout_intensity,
    COUNT(*) AS total_sessions_reaching_checkout,
    COUNTIF(has_purchased) AS successful_purchases,
    -- Checkout completion conversion rate
    ROUND(COUNTIF(has_purchased) * 100.0 / COUNT(*), 2) AS checkout_success_rate_pct
FROM order_2_frequency
GROUP BY 1, 2, 3
ORDER BY platform, esim_compatible, checkout_intensity;
