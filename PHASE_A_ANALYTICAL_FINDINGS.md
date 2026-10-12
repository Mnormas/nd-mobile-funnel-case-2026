# Saily Data Analyst Case Study: Phase A Analytical Findings & Evidence Dossier

**Document Type:** Formal Empirical Findings & Evidence Protocol (Deliverable A)  
**Candidate:** Mantas Normantas  
**Role Applied:** Data Analyst (Saily)  
**Organization:** Saily (Nord Security)  
**Evaluation Date:** October 2026  
**Data Environment:** Google Cloud BigQuery (`homework-data2020.saily_data_analyst`)  

---

## 1. Executive Summary of Phase A Empirical Findings

Through rigorous execution of the Phase A analytical protocol across `274,695` raw session rows and `115,995` engaged event sessions (`2024-08-01` to `2024-08-27`), the following critical empirical facts have been discovered, validated, and quantified:

1. **Data Engineering Anomaly & Three-Metric Conversion Reconciliation (`sql/01_data_audit.sql`):**
   * The raw `sessions` table contains **30,836 duplicate session identifiers** (`33,147` surplus rows) because converting sessions emit an initial row with `transaction_id IS NULL` followed by one or more rows with a populated `transaction_id`.
   * Calculating conversion naively (`25,133 / 274,695`) yields an understated **9.15% CR**.
   * Deduplicating by `unique_session_id` (`241,548` unique sessions) establishes two distinct institutional metrics:
     * **Strict Session Conversion Rate:** **10.12%** (`24,456` unique converting sessions / `241,548` unique sessions — the primary funnel KPI).
     * **Order-to-Session Ratio:** **10.40%** (`25,133` total transactions / `241,548` unique sessions — reflecting `677` multi-plan orders placed within the same session, or `1.028` orders per buyer).
2. **Platform & Hardware Funnel Divergence (`sql/02_funnel_and_markov.sql`):**
   * **iOS (`not_applicable`) Session CR:** **12.48%** (`16,088 / 128,872` sessions — benchmark performer).
   * **Android Compatible (`true`) Session CR:** **9.65%** (`8,258 / 85,603` sessions — trailing iOS by `2.84 pp` unrounded [`12.484% - 9.647%`], $Z = 20.28, p < 0.0001$, refuting **H1**).
   * **Android Incompatible (`false`) Session CR:** **0.41%** (`110 / 27,073` sessions — severe hardware barrier that drags blended Android CR down to **7.43%**).
3. **Late-Stage Friction & UX Trap (Hypothesis H2 Confirmed):**
   * `24.0%` of all Android traffic (`27,073` sessions) is on non-eSIM hardware. While `70.78%` (`19,162` sessions) bounce with zero events, **4,735 incompatible users reach Step 2 (`click_to_order_2`)**, where **97.68% (`4,625` sessions) drop off** immediately prior to purchase (`658` sessions attempt checkout 2+ times).
   * Furthermore, **110 distinct sessions (`111` transactions, `$1,238.19` gross billings)** bypassed the compatibility check and completed payment on `esim_compatible = 'false'` hardware, creating direct refund, chargeback, and Play Store review liability.
4. **Two Distinct Macro Anomalies Diagnosed (`sql/03_anomalies_and_corridors.sql`):**
   * **Positive Outlier (Friday, August 16):** All-time peak in purchases (**1,130 orders**) and revenue (**$16,240.64**, AOV `$14.37`), driven by weekend getaway seasonality (`Friday/Saturday Seasonality Index = 1.083 / 1.074`) and high-tier North American corridors (`US->US` 10GB/20GB and `CA->CA` 5GB).
   * **Negative Outlier (Tuesday, August 27 — H3 Explained):** Global iOS CR collapsed to **5.64%** due to an isolated viral/campaign traffic surge from **Morocco (`geo_country = 'Morocco'`)** accounting for `5,134` iOS sessions (`0.10%` CR, `5` purchases), where `97.8%` (`5,019` sessions) searched for domestic Moroccan data (`plan_destination = 'MA'`). Excluding Morocco restores iOS CR on August 27 to a healthy **11.36%** (`565 / 4,975`), and cross-cohort triangulation proves August 27 was a complete 24-hour day.
5. **Behavioral Topology, Pricing Economics & Commercial Sizing (`sql/04_economics_and_behavior.sql`):**
   * **Golden Engagement Window & Multi-Country Indecision (H8 Confirmed):** `92.57%` of all converting sessions (`22,638 / 24,456`) convert within **2–3 events** (**30.37% CR**), whereas conversion collapses to **5.91%** at `7+` events. Similarly, single-country browsers convert at **24.11%**, while users comparing `3+` countries drop to **6.69% CR**.
   * **Quota Exploration (H5 Rejected):** In a timestamp-free analysis (`COUNT(DISTINCT plan_quota)`), **92.16% of buyers (`22,512`)** inspect only a single quota tier and buy it; among the `1,909` multi-tier comparers, **63.4% (`1,211`) purchase the largest quota viewed**.
   * **Implied Promo Asymmetry (H7 Confirmed) & Hardware Sizing (H4 Confirmed):** iOS orders exhibit a **+4.43 pp lead** in below-list price realization (`25.50%` vs `21.07%` on Android); closing this gap models **+$39k to +$134k/yr** in incremental Android revenue. Meanwhile, the incompatible Android hardware barrier represents an upper-bound **$35,751.65 USD** (`~$483k/yr`) forfeited revenue benchmark and **-$39k to -$66k** per 27 days in modeled paid CAC bleed.

---

## 2. Module 1: Technical Data Quality & DAMA Governance Audit (`sql/01_data_audit.sql`)

Before conducting funnel or econometric modeling, the dataset was audited across all 8 DAMA data governance dimensions to eliminate structural table traps.

### 2.1. Primary Key Uniqueness, Session Deduplication & Multi-Order Grain (DAMA #1)
* **Raw Rows in `sessions`:** `274,695`
* **Distinct Session Identifiers (`unique_session_id`):** `241,548`
* **Duplicate Session IDs:** `30,836` distinct session IDs appear more than once, accounting for `33,147` surplus rows.
* **Distinct Transactions (`transaction_id IS NOT NULL`):** `25,133` completed orders generated across **`24,456` unique converting sessions** (indicating `677` secondary/multi-plan orders occurred within the same session, or `1.028` orders per converting session).
* **Structural Root Cause:** Whenever a session converts, the logging pipeline records one initial session row with `transaction_id IS NULL` and one (or more) additional rows with `transaction_id IS NOT NULL`.
* **Mandatory Governance Rule:** Joining `sessions` to `events` without first deduplicating `sessions` by `unique_session_id` duplicates every event for converting sessions! All downstream queries enforce strict session-level deduplication:

| Conversion Metric Definition | Mathematical Formula | Numerator | Denominator | Empirical Value | Analytical Usage |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Naive Unadjusted CR** | `COUNT(transaction_id) / COUNT(*)` | `25,133` orders | `274,695` raw rows | **9.15%** | **Invalid** (distorted by duplicate rows) |
| **Strict Session CR** | `COUNT(DISTINCT buy_session) / COUNT(DISTINCT session)` | `24,456` converting sessions | `241,548` unique sessions | **10.12%** | **Primary Funnel & Cohort KPI** |
| **Order-to-Session Ratio** | `COUNT(DISTINCT transaction_id) / COUNT(DISTINCT session)` | `25,133` total orders | `241,548` unique sessions | **10.40%** | **Gross Transaction Volume KPI** |

### 2.2. Referential Integrity & Deduplicated Cohort Bounce Rates (DAMA #2)
* **Matched Engaged Sessions (present in both `sessions` and `events`):** `115,995` (`48.02%` of unique sessions).
* **Zero-Event Bounced Sessions (present in `sessions`, absent in `events`):** `125,553` (`51.98%` of unique sessions).
* **Orphan Event Sessions (present in `events`, absent in `sessions`):** `1` session (`99.999%` referential integrity).
* **Deduplicated Bounce Rate by Platform & Compatibility Cohort:**

| Platform & Hardware Cohort | Total Unique Sessions | Engaged Sessions (`has_events = true`) | Bounced Sessions (`0 Events`) | Deduplicated Bounce Rate (%) |
| :--- | :--- | :--- | :--- | :--- |
| **Android Incompatible (`false`)** | `27,073` | `7,911` | `19,162` | **70.78%** |
| **Android Compatible (`true`)** | `85,603` | `44,913` | `40,690` | **47.53%** |
| **iOS (`not_applicable`)** | `128,872` | `63,171` | `65,701` | **50.98%** |
| **Total Global (Reconciled)** | **`241,548`** | **`115,995`** | **`125,553`** | **51.98%** |

* **Key Takeaway:** Incompatible Android users bounce upon app entry at a rate **23.25 percentage points higher** than compatible Android users (`70.78%` vs `47.53%`), reflecting immediate abandonment among users aware of their hardware limitation or encountering initial onboarding friction.

### 2.3. Financial Consistency, Tag Sync, Categorical & Temporal Hygiene (DAMA #3–#8)
* **Logical & Financial Boundary Checks (DAMA #3 & #8):** Across all `25,133` transactions (`$358,625.85` total gross billings, `$14.27` global AOV), `100.0%` have strictly positive revenue (`min = $0.99 USD`, `max = $179.99 USD`), with **0 null, zero, or negative billing rows**.
* **System Defect — Incompatible Hardware Purchases:** Exactly **110 distinct sessions (`111` transactions, `$1,238.19 USD` gross billings)** completed payment despite `esim_compatible = 'false'`. Because these devices lack eUICC hardware, these orders cannot be activated and represent a critical client-side gating bug.
* **Tag Synchronization (DAMA #4):** Out of `24,456` converting sessions, **24,427 (`99.88%`)** have matching records in `events` and **24,426 (`99.88%`)** explicitly logged `click_to_order_2`. Only **29 converting sessions (`0.12%`)** completed payment with `0` logged events (attributable to client ad-blockers or direct renewal flows).
* **Categorical Normalization & Temporal Continuity (DAMA #5 & #6):**
  * `platform` is strictly normalized into `'ANDROID'` (`112,676` unique sessions) and `'IOS'` (`128,872` unique sessions).
  * `esim_compatible` contains three exact string states: `'true'` (`85,603`), `'false'` (`27,073`), and `'not_applicable'` (`128,872` — all iOS).
  * `session_date` spans **`2024-08-01` to `2024-08-27`** (`27` active calendar days out of `27` expected; **0 missing dates**).
* **Client Loop / Tag Double-Firing Audit (DAMA #7):** Exactly **250 unique sessions (`0.10%` of traffic)** fired an identical event `>15` times within a single session (reaching up to **167 identical events** in one session), confirming isolated client retry loops and reinforcing why all funnel metrics must use `COUNT(DISTINCT unique_session_id)`.

---

## 3. Module 2: Conversion Funnel, Markov Hazard Dynamics & Platform Inference (`sql/02_funnel_and_markov.sql`)

Having established clean session grain, we evaluate user progression across the 4 observable funnel stages and test **Hypotheses H1 and H2**:
$$\text{Step 0: Session Start} \implies \text{Step 1: click\_to\_order\_1} \implies \text{Step 2: click\_to\_order\_2} \implies \text{Step 3: Purchase Transaction}$$

### 3.1. 4-Stage Segmented Conversion Funnel Matrix

| Platform & Cohort | Step 0: Unique Sessions | Step 1: Plan Select (`click_to_order_1`) | Step 2: Checkout (`click_to_order_2`) | Step 3: Converting Sessions | Overall Strict Session CR |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **iOS (`not_applicable`)** | `128,872` | `62,532` *(48.52%)* | `43,411` *(69.42%)* | `16,088` *(37.06%)* | **12.48%** |
| **Android Compatible (`true`)** | `85,603` | `44,666` *(52.18%)* | `25,273` *(56.58%)* | `8,258` *(32.68%)* | **9.65%** |
| **Android Incompatible (`false`)** | `27,073` | `7,889` *(29.14%)* | **`4,735`** *(60.02%)* | **`110`** *(2.32%)* | **0.41%** |
| **Total Blended Android** | `112,676` | `52,555` *(46.64%)* | `30,008` *(57.10%)* | `8,368` *(27.89%)* | **7.43%** |
| **Total Global (Reconciled)** | **`241,548`** | **`115,087`** *(47.65%)* | **`73,419`** *(63.79%)* | **`24,456`** *(33.31%)* | **10.12%** |

### 3.2. Two-Proportion Z-Test: Evaluating Hypothesis H1 (Hardware Asymmetry Alone)
To test **H1** (*"Does Compatible Android achieve conversion parity with iOS once incompatible devices are removed?"*), an independent two-proportion Z-test was executed:
* **iOS Cohort:** $x_1 = 16,088$ converting sessions, $n_1 = 128,872$ sessions ($p_1 = 12.48\%$).
* **Android Compatible Cohort:** $x_2 = 8,258$ converting sessions, $n_2 = 85,603$ sessions ($p_2 = 9.65\%$).
* **Pooled Proportion ($\hat{p}$):** $11.35\%$.
* **Empirical Test Statistic:** **$Z = 20.28, \quad p < 0.0001$** (99.9%+ confidence).
* **Verdict on H1 (Rejected):** Removing incompatible devices improves Android CR from `7.43%` to `9.65%`, eliminating `43.9%` of the raw platform gap (`5.05 pp` raw gap $\to$ `2.84 pp` compatible gap). However, Compatible Android still trails iOS by a highly significant **2.84 percentage points** (`12.484%` vs `9.647%`, a `22.7%` relative deficit), proving that secondary behavioral and commercial friction exists beyond hardware compatibility.

### 3.3. Stochastic Markov Transition Matrix & Terminal Hazard Dynamics (Testing H2)
Modeling the funnel as a discrete-time Markov chain across states $\{S_0, S_1, S_2, S_{\text{BUY}}, S_{\text{DROP}}\}$ isolates exactly *where* each cohort loses conversion momentum:

| Cohort | Baseline ($N$) | $P(S_0 \to S_1)$ | $P(S_0 \to \text{Drop})$ | $P(S_1 \to S_2)$ | $P(S_1 \to \text{Drop})$ | $P(S_2 \to \text{Buy})$ | Terminal Checkout Hazard ($S_2 \to \text{Drop}$) | Cumulative Win ($P_{\text{BUY}}$) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **iOS** | `128,872` | `48.52%` | `51.48%` | **69.42%** | **30.58%** | **37.06%** | **62.94%** | **12.48%** |
| **Android Compatible** | `85,603` | **52.18%** | `47.82%` | `56.58%` | `43.42%` | `32.68%` | `67.32%` | **9.65%** |
| **Android Incompatible** | `27,073` | `29.14%` | **70.86%** | `60.02%` | `39.98%` | **2.32%** | **97.68%** | **0.41%** |

1. **Top-of-Funnel Intent Advantage on Compatible Android ($S_0 \to S_1$):** Compatible Android users initiate plan selection at a **higher rate (`52.18%`) than iOS (`48.52%`)**, proving strong initial product appetite.
2. **Mid-Funnel Plan Configuration Gap ($S_1 \to S_2$):** Compatible Android suffers a **43.42% drop-off** between `click_to_order_1` and `click_to_order_2` compared to only **30.58% on iOS** (`-12.84 pp` transition deficit). As shown in Module 4, this aligns with Android's lower promotional discount penetration (`78.93%` exposed to full catalog prices).
3. **Catastrophic Late-Stage Hazard on Incompatible Android ($S_2 \to \text{Drop}$ — H2 Confirmed):** Incompatible Android users who pass Step 1 advance to Step 2 (`click_to_order_2`) at a normal **60.02% rate (`4,735` sessions)**, only to hit a **97.68% terminal drop hazard** (`4,625` sessions abandoned at checkout). This confirms **H2**: hardware incompatibility is not effectively blocked at app entry, allowing nearly 5,000 users to configure plans and click checkout before failing.

### 3.4. Checkout Retry Frequency & Payment Gateway Friction (`click_to_order_2` Loops)
Evaluating repeat `click_to_order_2` attempts within the exact deduplicated Step 2 cohorts (`4,735` Android Incompatible, `25,273` Android Compatible, `43,411` iOS; Query 12 in `sql/04_economics_and_behavior.sql`) reveals two distinct friction patterns:

| Platform | Hardware Compatibility | Checkout Intensity (`click_to_order_2`) | Unique Sessions Reaching Step 2 | Converting Sessions | Checkout Conversion Rate (%) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Android** | Incompatible (`false`) | `1 Attempt` (Standard Flow) | `4,077` | `96` | `2.35%` |
| **Android** | Incompatible (`false`) | **`2 Attempts` (Retry)** | **`504`** | `11` | `2.18%` |
| **Android** | Incompatible (`false`) | **`3+ Attempts` (Severe Loop)** | **`154`** | `3` | `1.95%` |
| **Android** | Compatible (`true`) | `1 Attempt` (Standard Flow) | `22,992` | `7,407` | `32.22%` |
| **Android** | Compatible (`true`) | `2 Attempts` (Retry) | `1,990` | `756` | `37.99%` |
| **Android** | Compatible (`true`) | `3+ Attempts` (Severe Loop) | `291` | `88` | `30.24%` |
| **iOS** | Not Applicable | `1 Attempt` (Standard Flow) | `39,258` | `14,711` | `37.47%` |
| **iOS** | Not Applicable | `2 Attempts` (Retry) | `3,539` | `1,244` | `35.15%` |
| **iOS** | Not Applicable | **`3+ Attempts` (Severe Loop)** | **`614`** | **`110`** | **`17.92%` (-52.2%)** |

* **Incompatible Retry Frustration:** `658` incompatible Android sessions (`13.9%` of the `4,735` reaching Step 2) clicked `click_to_order_2` two or more times (`504` twice, `154` 3+ times), repeatedly attempting to bypass the checkout barrier.
* **iOS 3+ Attempt Payment Cliff:** Across compatible users, `6,434` sessions (`2,281` Android Compatible + `4,153` iOS) clicked checkout 2+ times. On iOS, sessions requiring `3+` checkout clicks suffer a **52.2% collapse in checkout conversion (`37.47%` $\to$ `17.92%`)**, pointing to Apple Pay sheet cancellation or 3DS card authorization failures on repeated attempts.

---

## 4. Module 3: Macro Anomaly Deconstruction, Seasonality & Geographic Corridors (`sql/03_anomalies_and_corridors.sql`)

To ensure longitudinal stability and test **Hypotheses H3 and H6**, we deconstruct daily conversion anomalies, weekly travel cyclicality, global origin-destination corridors, and geographic confounding.

### 4.1. Negative Outlier: August 27 iOS Conversion Collapse (Testing H3)

#### Empirical Facts & Control Group Comparison
* **Date:** Tuesday, August 27, 2024.
* **iOS Traffic Surge:** iOS sessions surged from a `~4,400` Tuesday baseline to **`10,109` unique sessions (`+122%` surge)**.
* **iOS Purchase Stability:** iOS converting sessions remained completely normal at **`570`** (vs Tuesday baseline of `561.0`).
* **Observed iOS CR Collapse:** Because sessions more than doubled while purchases remained constant, headline iOS CR collapsed from `~13.0%` to **`5.64%`**.
* **Android Control Group:** Compatible Android CR remained completely stable at **`8.64%`** (`325` converting sessions / `3,761` sessions), proving the anomaly was strictly isolated to iOS traffic composition.

#### Root Cause Isolation: The Morocco Viral / Campaign Surge
Segmenting August 27 iOS sessions by `geo_country` and cross-referencing `events.plan_destination` isolates the exact source of the unconverting traffic:

| Origin Market (`geo_country`) | iOS Sessions (Aug 27) | Converting Sessions | Session CR (%) | Share of Aug 27 iOS Sessions | Primary Browsed Destination (`plan_destination`) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Morocco (`MA`)** | **`5,134`** | **`5`** | **`0.10%`** | **`50.8%`** | **`MA` (`97.8%` domestic intent across engaged `MA` sessions)** |
| **United States** | `1,637` | `180` | `11.00%` | `16.2%` | International & North American travel |
| **United Kingdom** | `1,412` | `118` | `8.36%` | `14.0%` | European & Turkish travel |
| **Canada** | `905` | `158` | `17.46%` | `9.0%` | US & European travel |
| **All Other Countries** | `1,021` | `109` | `10.68%` | `10.0%` | Global outbound travel |
| **Total iOS Ex-Morocco (Normalized)** | **`4,975`** | **`565`** | **`11.36%`** | **`49.2%`** | **Normal Healthy Baseline Restored** |

* **Operational Diagnosis (H3 Explained):** Between Aug 1 and Aug 20, Morocco generated `~180` sessions/day (`~10.5%` CR). Starting Aug 22, Moroccan sessions surged exponentially (`180` $\to$ `650` $\to$ `1,723` $\to$ `5,787` total sessions across iOS and Android on Aug 27). Across all `5,787` Moroccan sessions on Aug 27, `5,134` session-destination pairs were logged in `events`, of which **97.8% (`5,019` engaged sessions) searched strictly for local Moroccan data (`plan_destination = 'MA'`)** while only `115` searched for international destinations. Local users seeking cheap domestic mobile data encountered international tourist USD rates and immediately abandoned.

#### Data Governance Proof: Full 24-Hour Day vs. Truncated Partial Day Audit
Because `sessions` records only `session_date` (`DATE`) without intraday timestamps, we rigorously tested whether August 27 could be a truncated partial day (pipeline cutoff):
1. **All-Time Record Session Volume:** A noon pipeline cutoff would reduce daily traffic by ~50%. Instead, August 27 recorded **`15,281` total unique sessions** (`10,109` iOS + `5,172` Android) — the single highest traffic day of the entire 27-day dataset.
2. **Android Control Group Order Parity:** Total Android recorded **`328` converting sessions** on August 27, representing **115.2% of the prior three Tuesdays' average** (`284.7` converting sessions across Aug 6, Aug 13, and Aug 20).
3. **Organic iOS Order Parity:** iOS recorded **`570` converting sessions** (**101.6% of the prior Tuesday average** of `561.0`), with `565` orders outside Morocco.
4. **Conclusion:** August 27 is 100% temporally complete. The CR drop was caused by **Denominator Inflation** (`+5,134` non-converting Moroccan iOS sessions), not **Numerator Starvation**.

### 4.2. Positive Outlier (August 16 Peak) & Day-of-Week Seasonality Index

#### August 16 All-Time Revenue Peak
* **Date:** Friday, August 16, 2024 — all-time record of **`1,130` transactions** and **`$16,240.64` gross billings** (`$14.37` AOV), with simultaneous period conversion highs on **iOS (`14.83%` CR)** and **Compatible Android (`10.98%` CR)**.
* **Corridor & Quota Drivers:** Driven by high-capacity North American weekend departures: `United States -> US (20 GB)` (`19` orders, `$697.26`, `$36.70` AOV), `United States -> US (10 GB)` (`21` orders, `$475.19`), `Canada -> CA (5 GB)` (`23` orders, `$405.67`), and `Canada -> US (3 GB)` (`42` orders, `$348.93`).

#### Top 5 Revenue Days & Weekly Cyclicality (`sql/04_economics_and_behavior.sql` Query 7)
All Top 5 revenue days in August 2024 occurred on **Thursday, Friday, or Saturday** (`Aug 16 Fri: $16,240.64`, `Aug 24 Sat: $15,663.55`, `Aug 17 Sat: $15,062.72`, `Aug 23 Fri: $15,039.64`, `Aug 15 Thu: $14,345.20`). Aggregating across all 27 days establishes the **Day-of-Week Seasonality Index**:

| Day of Week | Occurrences | Avg Daily Distinct Sessions | Avg Daily Converting Sessions | Avg Daily Revenue (USD) | Observed Avg CR (%) | Demand Seasonality Index (Orders) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Sunday** | `4` | `9,266.5` | `913.0` | `$13,145.26` | `9.85%` | `1.011` *(Baseline)* |
| **Monday** | `4` | `9,642.5` | `895.0` | `$13,416.24` | `9.28%` | `0.991` |
| **Tuesday (All 4 — Incl. Aug 27)** | `4` | `10,355.5` *(8,713.7 norm.)* | `858.8` *(845.7 norm.)* | `$12,760.99` | `8.29%` *(9.71% norm.)* | `0.951` *(Mid-week trough)* |
| **Wednesday** | `3` | `8,752.0` | `833.0` | `$12,449.33` | `9.52%` | **`0.922` *(Lowest demand)*** |
| **Thursday** | `4` | `8,870.8` | `876.0` | `$12,757.69` | `9.88%` | `0.970` |
| **Friday** | `4` | **`8,813.0`** | **`978.0`** | **`$14,119.35`** | **`11.10%`** | **`1.083` *(+8.3% Peak)*** |
| **Saturday** | `4` | **`8,907.3`** | **`969.8`** | **`$14,119.94`** | **`10.89%`** | **`1.074` *(+7.4% Peak)*** |

* **Methodological Note on Tuesday (`8,713.7` Normalized vs. `10,355.5` Observed):** Observed Tuesday average sessions (`10,355.5/day` across 4 Tuesdays = `41,422` session-days) and observed CR (`8.29%`) are skewed by the August 27 Morocco traffic spike (`15,281` sessions). Subtracting August 27 leaves `26,141` sessions across the three normal Tuesdays (Aug 6, 13, 20), averaging **`8,713.7` sessions/day** and **`9.71%` CR** (`845.7` converting sessions/day), confirming a genuine Tuesday–Wednesday mid-week demand trough (`Index 0.922–0.951`) compared to the **Friday–Saturday pre-departure peak (`Index 1.074–1.083`, `11.10% / 10.89%` CR)**.
* **Daily Session-Date vs. Global Session Grain Reconciliation (`249,678` vs. `241,548`):** Summing `Occurrences × Avg Daily Distinct Sessions` across all 27 calendar dates yields `249,678` daily session-date instances (`24,461` converting session-date instances), compared to `241,548` globally distinct `unique_session_id`s (`24,456` converting sessions). The difference of **`8,130` sessions (`3.37%`)** represents sessions spanning UTC midnight across two consecutive `session_date` calendar days.

### 4.3. Global Revenue Corridors & Buyer Archetype Clustering

#### Top 10 Origin $\to$ Destination Revenue Corridors (`25,133` Total Orders)

| Origin Country (`geo_country`) | Destination (`transaction_plan_destination`) | Total Orders | Gross Revenue (USD) | AOV (USD) | Share of Global Revenue (%) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **United States** | **US (In-Destination)** | **`3,572`** | **`$46,731.93`** | **`$13.08`** | **`13.03%`** |
| **Canada** | **US (Cross-Border)** | **`2,333`** | **`$27,915.52`** | **`$11.97`** | **`7.78%`** |
| **Canada** | **CA (In-Destination)** | **`1,376`** | **`$23,423.08`** | **`$17.02`** | **`6.53%`** |
| **United Kingdom** | **GB (In-Destination)** | `924` | `$11,342.25` | `$12.28` | `3.16%` |
| **United Kingdom** | **US (Transatlantic)** | `545` | `$9,960.85` | `$18.28` | `2.78%` |
| **United Kingdom** | **TR (Turkey)** | `666` | `$8,687.09` | `$13.04` | `2.42%` |
| **Canada** | **IT (Italy)** | `414` | `$8,103.91` | `$19.57` | `2.26%` |
| **Canada** | **AT (Austria)** | `282` | `$7,800.16` | **`$27.66`** | `2.18%` |
| **United States** | **AT (Austria)** | `250` | `$6,039.16` | **`$24.16`** | `1.68%` |
| **United States** | **IT (Italy)** | `343` | `$5,646.22` | `$16.46` | `1.57%` |

#### Behavioral Buyer Archetype Clustering (`sql/04_economics_and_behavior.sql` Query 8)
Grouping all `25,133` orders (`$358,625.85`) by origin-destination relationship isolates four commercial archetypes:

| Strategic Buyer Archetype | Total Orders | Share of Orders (%) | Gross Revenue (USD) | Share of Revenue (%) | AOV (USD) | Avg Quota (GB) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **1. Regional Cross-Border Travel** | `16,034` | `63.80%` | `$222,439.80` | `62.03%` | `$13.87` | `6.7 GB` |
| **2. In-Destination Purchase (On-Arrival Traveler / Local Backup SIM)** | **`5,939`** | **`23.63%`** | **`$82,100.94`** | **`22.89%`** | **`$13.82`** | **`5.5 GB`** |
| **3. Long-Haul Transatlantic Explorer (`US/CA -> Europe`)** | **`3,026`** | **`12.04%`** | **`$52,285.60`** | **`14.58%`** | **`$17.28`** | **`9.5 GB`** |
| **4. Accidental Domestic (Morocco `MA -> MA`)** | `134` | `0.53%` | `$1,799.51` | `0.50%` | `$13.43` | `2.4 GB` |
| **Total Global (Reconciled)** | **`25,133`** | **`100.00%`** | **`$358,625.85`** | **`100.00%`** | **`$14.27`** | **`6.7 GB`** |

* **Architectural Insight on In-Destination Purchases (`22.89%` of Revenue):** Because `geo_country` reflects IP geolocation at session start (`US->US`, `CA->CA`, `GB->GB`, `LT->LT`), this `$82,100.94` segment captures two high-value behaviors: **(a) On-Arrival International Travelers** who land at a destination airport, connect to terminal Wi-Fi (receiving a destination IP), and purchase an eSIM immediately upon arrival, and **(b) Domestic Backup SIM Users** purchasing secondary local data or hotspot failover.
* **Transatlantic Premium:** Long-haul North American travelers heading to Europe (`AT`, `IT`, `FR`, `ES`, `DE`, `GB`, `GR`) generate the highest unit basket (`$17.28` AOV, `9.5 GB` average quota, reaching `$24.16–$27.66` AOV on Austrian plans).

### 4.4. Testing Hypothesis H6: Geographic Bias & Simpson's Paradox
To test **H6** (*"Is iOS outperformance merely a Simpson's Paradox artifact caused by iOS having a higher share of wealthy Tier-1 countries?"*), conversion was evaluated within every country with $\ge 1,000$ sessions:

| Market (`geo_country`) | iOS CR (%) | Android Compatible CR (%) | iOS Conversion Lead (pp) | Outperforming Platform |
| :--- | :--- | :--- | :--- | :--- |
| **Romania** | `13.94%` | `6.92%` | **`+7.02 pp`** | iOS Outperforms |
| **Czechia** | `17.06%` | `10.85%` | **`+6.21 pp`** | iOS Outperforms |
| **Canada** | `20.59%` | `14.66%` | **`+5.93 pp`** | iOS Outperforms |
| **Sweden** | `11.83%` | `6.45%` | **`+5.38 pp`** | iOS Outperforms |
| **Norway** | `15.02%` | `9.78%` | **`+5.24 pp`** | iOS Outperforms |
| **Lithuania** | `14.70%` | `10.07%` | **`+4.63 pp`** | iOS Outperforms |
| **Poland** | `11.11%` | `6.79%` | **`+4.31 pp`** | iOS Outperforms |
| **Ireland** | `14.01%` | `10.76%` | **`+3.25 pp`** | iOS Outperforms |
| **United States** | `12.53%` | `9.46%` | **`+3.07 pp`** | iOS Outperforms |
| **United Kingdom** | `9.61%` | `8.25%` | **`+1.36 pp`** | iOS Outperforms |
| **Morocco** *(Skewed by Aug 27 iOS Surge)* | `2.31%` | `4.83%` | `-2.52 pp` | Android Compatible Outperforms |

* **Verdict on H6 (Rejected):** iOS outperforms Compatible Android across **10 out of 11 major markets** (and all 10 normal markets outside the August 27 Morocco anomaly). Platform divergence is structurally universal across both Tier-1 North American/Western European markets and Central/Eastern European markets.

---

## 5. Module 4: Behavioral Navigation Topology, Pricing Economics & Prescriptive P&L Simulations (`sql/04_economics_and_behavior.sql`)

Having ruled out geographic Simpson's Paradox (H6), we examine in-app behavioral patterns, pricing elasticity, implied promotional discounts, and commercial opportunity sizing (**Hypotheses H4, H5, H7, and H8**).

### 5.1. Search Fatigue & The "Golden Engagement Window" (Testing H8 — Deduplicated Session Grain)
Evaluating conversion across event depth buckets across all `241,548` deduplicated unique sessions and `24,456` unique converting sessions:

| Browsing Depth Tier | Unique Sessions | Converting Sessions | Session CR (%) | Share of All Sessions (%) |
| :--- | :--- | :--- | :--- | :--- |
| **0 Events (Bounced)** | `125,553` | `29` | `0.02%` | `51.98%` |
| **1 Event (Single Interaction Abandon)** | `31,305` | `429` | `1.37%` | `12.96%` |
| **2–3 Events (Focused Intent / Golden Window)** | **`74,546`** | **`22,638`** | **`30.37%`** | **`30.86%`** |
| **4–6 Events (Comparative Browsing)** | `7,960` | `1,231` | **`15.46%` *(-49.1% vs Golden)*** | `3.30%` |
| **7+ Events (Search Fatigue / Maze)** | `2,184` | `129` | **`5.91%` *(-80.5% vs Golden)*** | `0.90%` |
| **Total Global (Reconciled)** | **`241,548`** | **`24,456`** | **`10.12%`** | **`100.00%`** |

* **The Golden Horizon:** **92.57% of all converting sessions (`22,638 / 24,456`)** occur within a decisive **2 to 3 event window** (`click_to_order_1` $\to$ `click_to_order_2` $\to$ Purchase), converting at **30.37%**.
* **Monotonic Search Fatigue Cliff:** Beyond 3 events, conversion drops by **49.1% to `15.46%`** at `4–6` events, and **collapses by 80.5% to `5.91%`** at `7+` events.

### 5.2. Destination Indecision & Regional vs. Single-Country Cross-Shopping (Testing H8)
Evaluating conversion across all `115,995` deduplicated engaged sessions by the number of distinct destinations (`COUNT(DISTINCT plan_destination)`) viewed:

| Destination Browsing Behavior | Engaged Sessions | Converting Sessions | Engaged Session CR (%) | Share of Engaged Sessions (%) |
| :--- | :--- | :--- | :--- | :--- |
| **Single Destination Focus (`1 Country`)** | **`91,117`** | **`21,970`** | **`24.11%`** | **`78.55%`** |
| **Multi-Destination (`2 Countries`)** | `14,603` | `1,770` | **`12.12%` *(-49.7%)*** | `12.59%` |
| **Indecision Loop (`3+ Countries`)** | `10,275` | `687` | **`6.69%` *(-72.3%)*** | `8.86%` |
| **Total Engaged Sessions (Reconciled)** | **`115,995`** | **`24,427`** *(+29 w/ 0 events = 24,456)* | **`21.06%`** | **`100.00%`** |

* **Multi-Country Erosion (H8 Confirmed):** `24,878` engaged sessions (`21.45%`) compare multiple destinations in a single session, suffering a **49.7% to 72.3% conversion drop** (`24.11%` $\to$ `12.12%` $\to$ `6.69%`).
* **Within-Session Destination Cross-Shopping (`EU` $\leftrightarrow$ `AT`):** Across all `24,456` unique converting sessions (`Query 11`), **21,349 (`87.29%`)** viewed exclusively their purchased destination, **3,078 (`12.59%`)** cross-shopped at least one alternative destination in the same session (`e.plan_destination != s.transaction_plan_destination`), and `29` (`0.12%`) had no events (`21,349 + 3,078 + 29 = 24,456`). Among the `3,078` cross-shopping buyers, the **#1 pair is `EU` (Europe Regional) alongside `AT` (Austria) with `693` converting sessions (`22.51%`)**, followed by `US <-> GB` (`79` sessions, `2.57%`), `CA <-> US` (`74` sessions, `2.40%`), `US <-> CA` (`74` sessions, `2.40%`), `GLB <-> AE` (`65` sessions, `2.11%`), `ASA <-> AU` (`55` sessions, `1.79%`), `NAM <-> CA` (`51` sessions, `1.66%`), `GLB <-> US` (`50` sessions, `1.62%`), and `EU <-> GB` (`48` sessions, `1.56%`). Multi-country travelers actively weigh Regional/Global Passes (`EU`, `GLB`, `ASA`, `NAM`) against single-country plans and need an automated **Multi-Country Regional Bundle Prompt** when 2+ countries in the same region are searched.

### 5.3. Quota Exploration Behavior: Testing Hypothesis H5 (Timestamp-Free Analysis)
Because `events` lacks `event_timestamp`, chronological ordering of quota clicks within a session cannot be assumed. Evaluating converting sessions (`24,426` with quota events) via timestamp-free set cardinality (`COUNT(DISTINCT plan_quota)`) vs. purchased quota (`transaction_plan_quota`):

| Quota Exploration Behavior (Timestamp-Free) | Converting Sessions | Share of Converting Sessions (%) | Behavioral Interpretation |
| :--- | :--- | :--- | :--- |
| **Single Quota Viewed & Purchased (`distinct_quotas = 1`)** | **`22,512`** | **`92.16%`** | **Decisive Intent:** User inspected 1 quota tier and bought that exact tier. |
| **Multi-Quota Explored $\to$ Bought Largest (`purchased = MAX`)** | **`1,211`** | **`4.96%`** | **Upper Selection:** User compared 2+ tiers and bought the largest viewed tier (`63.4%` of multi-quota comparers). |
| **Multi-Quota Explored $\to$ Bought Smallest (`purchased = MIN`)** | **`668`** | **`2.73%`** | **Lower Selection:** User compared 2+ tiers and bought the smallest viewed tier (`35.0%` of multi-quota comparers). |
| **Multi-Quota Explored $\to$ Bought Middle Tier** | `30` | `0.12%` | User compared 3+ tiers and selected an intermediate quota. |
| **Unmatched / Other** | `5` | `0.02%` | Purchased quota differed from logged event quotas. |
| **Total Converting Sessions with Quota Events (Reconciled)** | **`24,426`** | **`100.00%`** | **`23,723` (`97.12%`) Bought Max Viewed; `703` (`2.88%`) Bought Other** |

#### Cross-Tabulation: Maximum Browsed Quota (`MAX(plan_quota)`) vs. Purchased Quota (`purchased_gb`) across `24,426` Converting Sessions

| Maximum Browsed Tier (`MAX(plan_quota)`) | 1 GB Bought | 2 GB Bought | 3 GB Bought | 5 GB Bought | 10 GB Bought | 20 GB Bought | 50–100 GB Bought | Row Total Sessions | Bought Max Viewed (%) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **1 GB Max Viewed** | **`5,455`** | `0` | `1` | `0` | `0` | `0` | `0` | `5,456` | **`99.98%`** |
| **2 GB Max Viewed** | `1` | **`16`** | `0` | `0` | `0` | `0` | `0` | `17` | **`94.12%`** |
| **3 GB Max Viewed** | `142` | `2` | **`5,019`** | `1` | `0` | `0` | `0` | `5,164` | **`97.19%`** |
| **5 GB Max Viewed** | `60` | `0` | `129` | **`5,362`** | `1` | `0` | `0` | `5,552` | **`96.58%`** |
| **10 GB Max Viewed** | `39` | `0` | `21` | `132` | **`4,233`** | `0` | `0` | `4,425` | **`95.66%`** |
| **20 GB Max Viewed** | `36` | `1` | `10` | `21` | `105` | **`3,597`** | `0` | `3,770` | **`95.41%`** |
| **50–100 GB Max Viewed** | `0` | `0` | `0` | `0` | `0` | `0` | **`42`** *(31×50GB, 10×100GB, 1×100->50GB)* | `42` | **`97.62%`** *(41 / 42)* |
| **Total Converting Sessions** | **`5,733`** | **`19`** | **`5,180`** | **`5,516`** | **`4,339`** | **`3,597`** | **`42`** | **`24,426`** | **`97.12%` *(23,723 / 24,426)*** |

* **Verdict on H5 (Rejected):** **92.16% of buyers (`22,512`)** inspect only a single quota tier and purchase it, and **97.12% (`23,723 / 24,426`)** purchase the maximum quota tier they viewed (`703` off-diagonal sessions across the entire matrix). Among the `1,909` multi-tier comparers, **63.4% (`1,211`) choose the largest tier** versus `35.0%` (`668`) choosing the smallest. Users do not systematically down-trade to 1 GB due to price shock; abandonment is binary.

### 5.4. Unit Economics ($/GB), Implied Price Concessions & Android Promo Parity Simulation (Testing H7)

#### Volume Discounting & Unit Economics ($/GB Elasticity)
Across primary destinations, Saily's catalog delivers steep volume discounts between 1 GB and 10 GB tiers:
* **United States (`US`):** `1 GB` averages `$3.66/GB` on iOS (`$3.81/GB` on Android; list `$3.99`, promo floor `$0.99`), dropping to `$2.83/GB` at `3 GB`, `$2.69/GB` at `5 GB`, and **`$2.24/GB` (`-39%` vs iOS 1 GB / `-41%` vs Android 1 GB) at `10 GB`** (`$22.41` avg price).
* **Canada (`CA`):** `1 GB` averages `$5.12/GB` (list `$5.99`), dropping to **`$3.08/GB (-40%)` at `10 GB`** (`$30.85` avg price).
* **Turkey (`TR`):** `1 GB` averages `$3.47/GB` (list `$3.99`, floor `$0.99`), dropping to **`$1.53/GB (-56%)` at `10 GB`** (`$15.30` avg price).

#### Implied Price Concession & Promotional Penetration Analysis (Testing H7)
By comparing realized `total_billings_in_usd` against the maximum observed catalog price `MAX(total_billings_in_usd)` within each exact `(transaction_plan_destination, transaction_plan_quota)` pair (an *Implied Price Concession* proxy capturing referral vouchers, percentage promos, `$0.99` intro hooks, and minor regional/FX store variances), we quantify cross-platform pricing realization across all `25,133` orders:

| Platform | Realized Pricing Tier | Total Orders | Share of Platform Orders (%) | Avg Realized Price (USD) | Avg Implied Concession (USD) | Total Realized Revenue (USD) | Total Implied Concession Pool (USD) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Android** | Full Catalog Max Price | `6,793` | `78.93%` | `$13.82` | `$0.00` | `$93,869.61` | `$0.00` |
| **Android** | **Below-Max Price (Implied Voucher / Promo)** | **`1,733`** | **`20.14%`** | **`$13.98`** *(larger GB mix)* | **`$5.53`** | `$24,234.84` | **`$9,578.89`** |
| **Android** | **Intro Promo (`$0.99` Hook Tier)** | **`80`** | **`0.93%`** | **`$0.99`** | **`$3.41`** | `$79.20` | **`$272.80`** |
| **Android Subtotal** | **All Android Orders (`21.07%` Below-Max)** | **`8,606`** | **`100.00%`** | **`$13.73`** | **`$1.14 / order`** | **`$118,183.65`** | **`$9,851.69` *(7.69% rate)*** |
| **iOS** | Full Catalog Max Price | `12,312` | `74.50%` | `$15.04` | `$0.00` | `$185,157.84` | `$0.00` |
| **iOS** | **Below-Max Price (Implied Voucher / Promo)** | **`3,983`** | **`24.10%`** | **`$13.83`** | **`$5.18`** | `$55,054.68` | **`$20,649.99`** |
| **iOS** | **Intro Promo (`$0.99` Hook Tier)** | **`232`** | **`1.40%`** | **`$0.99`** | **`$3.17`** | `$229.68` | **`$735.44`** |
| **iOS Subtotal** | **All iOS Orders (`25.50%` Below-Max)** | **`16,527`** | **`100.00%`** | **`$14.55`** | **`$1.29 / order`** | **`$240,442.20`** | **`$21,385.43` *(8.17% rate)*** |
| **Total Global** | **All Transactions Reconciled** | **`25,133`** | **`100.00%`** | **`$14.27`** | **`$1.24 / order`** | **`$358,625.85`** | **`$31,237.12` *(8.01% rate)*** |

* **Note on Android Discounted AOV (`$13.98` vs `$13.82`):** On Android, below-max price orders exhibit a slightly higher average realized bill (`$13.98`) than full-price orders (`$13.82`) because percentage vouchers are disproportionately redeemed on higher-capacity `10 GB` and `20 GB` plans (`$19.51` theoretical list AOV minus `$5.53` discount = `$13.98`), whereas full-price Android orders skew heavily toward `1 GB` and `3 GB` plans.
* **Methodological Governance (`MAX(price)` Upper-Tail Sensitivity vs. `MODE(price)`):** Because `sessions` lacks a `list_price` or `promo_code` column, using `MAX(total_billings_in_usd)` per `(destination, quota)` is sensitive to single-order upper-tail outliers (for example, on `Canada 10 GB`, `Max Price = $43.99` while `Avg Price = $30.85`, causing standard `$30.99` orders to be classified as `$13` below max). Thus, the `$31,237.12` concession pool and `$5.18–$5.53` average markdown represent an **upper-bound price dispersion proxy**; in production reporting without a catalog dimension table, benchmarking against the **modal price (`MODE`)** is recommended to isolate true voucher redemptions from FX/store outliers.
* **Verdict on H7 (Confirmed via Implied Proxy):** **25.50% of iOS orders** transact below maximum catalog price compared to **21.07% on Android** (`+4.43 pp` iOS advantage; `$1.29` vs `$1.14` average concession per order). Higher exposure to full catalog prices (`78.93%` on Android) directly contributes to Compatible Android's steeper $S_1 \to S_2$ plan-selection drop-off (`43.42%` vs `30.58%` on iOS).

#### "Level the Playing Field": Android Promotional Parity P&L Simulation
Modeling the financial impact of closing the `+4.43 pp` promotional gap on Compatible Android (`85,603` sessions, `8,258` converting sessions generating `8,495` total orders and `$116,945.46` baseline revenue — equal to `$13.77` per individual transaction or **`$14.16` realized billings per converting session**) via a targeted promo subsidy (`-$0.50` blended concession per converting session):
* **Conservative Scenario (`+0.60 pp` CR $\to$ `10.25%` CR at `$13.66` per converting session):** Generates **`8,772` converting sessions (`+514` net incremental buyers)** and **`$119,833.24` revenue**, yielding **+$2,887.78 USD net incremental gain per 27 days (`+$39,000 USD/year`)**.
* **Optimistic Scenario (`+1.20 pp` CR $\to$ `10.85%` CR at `$13.66` per converting session):** Generates **`9,285` converting sessions (`+1,027` net incremental buyers)** and **`$126,850.02` revenue**, yielding **+$9,904.56 USD net incremental gain per 27 days (`+$134,000 USD/year`)**.

### 5.5. Addressable Hardware Opportunity Sizing & Paid CAC Bleed Modeling (Testing H4)

#### Theoretical Upper-Bound Revenue Forfeited to Incompatible Android Hardware (`sql/02_funnel_and_markov.sql` Query 4)
* **Incompatible Android Cohort ($N_{\text{incompat}}$):** `27,073` unique sessions (`110` existing converting sessions / `111` orders, `$1,238.19` actual gross billings).
* **Compatible Android Benchmark ($\text{CR}_{\text{compat}}, \text{ARPPU}_{\text{compat}}$):** `9.6469%` Session CR (`8,258 / 85,603`) and **`$14.1615` Realized Revenue per Converting Session** (`$116,945.46` across `8,258` converting sessions, which corresponds to `8,495` orders at `$13.77` per order).
* **Upper-Bound Valuation:**
  $$\text{Potential Converting Sessions} = 27,073 \times 9.6469\% = 2,612\text{ converting sessions} \quad (\text{Net Incremental: } 2,612 - 110 = 2,502)$$
  $$\text{Net Forfeited Revenue Benchmark} = (2,612 \times \$14.1615) - \$1,238.19 = \$36,989.84 - \$1,238.19 = \mathbf{\$35,751.65\text{ USD / 27 days}} \quad (\mathbf{\sim\$483,300\text{ / year}})$$
  *(Note: Multiplying unrounded continuous floats `27,073 × (8,258/85,603) × ($116,945.46/8,258) - $1,238.19` yields **`$35,747.25 USD`**; both columns are output in `sql/02_funnel_and_markov.sql` Query 4).*
* **Methodological Caveat (Upper-Bound Assumption):** Because non-eSIM Android devices are predominantly older or entry-level budget handsets whose owners have lower discretionary travel budgets than flagship Android users, **`$35,751.65` (`~$483.3k/yr`) represents the theoretical upper-bound ceiling** if those sessions had occurred on eSIM-compatible hardware. Because Saily cannot upgrade a user's physical phone, the primary commercial lever for this cohort is **preventing wasted paid acquisition spend (CAC Bleed)** at the ad-network targeting layer.

#### Prescriptive Paid CAC Bleed Sensitivity Matrix (`sql/04_economics_and_behavior.sql` Query 6)
Because `27,073` incompatible sessions generate only `$1,238.19` in gross revenue (`$0.046` revenue per session — a `97%` loss on every `$1.50` spent), we model net acquisition bleed across simulated blended CAC per session tiers:

| Simulated Blended CAC / Session | Incompatible Sessions | Estimated Ad Spend Wasted | Gross Revenue Realized | Net Acquisition P&L Bleed (27 Days) | Annualized P&L Bleed (365 Days) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`$0.75 USD`** *(Low-Cost / 50% Paid Share)* | `27,073` | `$20,304.75` | `$1,238.19` | **`-$19,066.56 USD`** | `-$257,750 / yr` |
| **`$1.50 USD`** *(Industry Benchmark Blended)* | `27,073` | `$40,609.50` | `$1,238.19` | **`-$39,371.31 USD`** | **`-$532,240 / yr`** |
| **`$2.50 USD`** *(High-Tier Paid Social/Display)* | `27,073` | `$67,682.50` | `$1,238.19` | **`-$66,444.31 USD`** | **`-$898,230 / yr`** |
| **`$3.50 USD`** *(Competitive Travel Search Paid)* | `27,073` | `$94,755.50` | `$1,238.19` | **`-$93,517.31 USD`** | `-$1,264,215 / yr` |

* **Methodological Caveat (Paid Attribution Sensitivity & Play Console Device Gating):** Because the BigQuery schema does not include `utm_source` / `utm_medium` or actual marketing spend tables, the `27,073` sessions represent combined paid and organic traffic. The tiers above act as an **effective blended CAC sensitivity table** (e.g., if `50%` of incompatible traffic is paid at `$3.00` CPI, the effective blended cost across all `27,073` sessions is identical to the `$1.50` tier: **`-$39,371.31` net loss every 27 days**). Enforcing OEM device exclusion lists in Meta/Google Ads alongside **Google Play Console Device Catalog gating (`<uses-feature android:name="android.hardware.telephony.euicc" />` in `AndroidManifest.xml`)** ensures Google App Campaigns (UAC) and the Play Store automatically block installs and ad spend on non-eSIM handsets.

---

## 6. Epistemological Governance & Production SQL Inventory

### 6.1. Epistemological Governance Matrix: Hard Data vs. Interpretations vs. Assumptions

| Analytical Domain | Hard Empirical Data (100% Observed in BigQuery) | Analytical Interpretation (Evidence-Based Inference) | Explicit Assumptions & Schema Boundaries |
| :--- | :--- | :--- | :--- |
| **1. Session Deduplication & Multi-Order Grain** | `274,695` raw rows vs `241,548` distinct `unique_session_id`. `25,133` transactions occurred across `24,456` unique converting sessions (`10.12%` Strict Session CR; `10.40%` Orders/Session). | Converting sessions emit a base session row (`transaction_id IS NULL`) plus one or more transaction rows (`677` secondary orders occurred within the same session). | Deduplication by `unique_session_id` is mandatory; failing to deduplicate `sessions` before joining `events` inflates event counts for buyers. |
| **2. Late-Stage Incompatible Drop-Off (H2)** | `27,073` Android Incompatible sessions (`70.78%` bounce rate); `4,735` reach `click_to_order_2`, where `97.68%` drop off and `110` sessions complete payment (`$1,238.19`). | Compatibility friction is not fully gated at app entry; nearly 5,000 incompatible users reach checkout before abandoning, and 110 bypass the check entirely. | While we do not observe client UI screens directly, `4,735` sessions firing `click_to_order_2` proves the checkout trigger was accessible to non-eSIM devices. |
| **3. Aug 27 iOS CR Collapse (`5.64%` — H3)** | iOS sessions spiked to `10,109` on Aug 27 (`5,134` from Morocco at `0.10%` CR; `97.8%` of engaged Moroccan sessions viewing `MA` plans). Excluding Morocco, iOS CR is `11.36%`. | The dip was caused by denominator inflation from local Moroccan traffic seeking domestic data, not a technical outage or partial-day pipeline cutoff. | Because `utm_source` is absent from the schema, the Morocco spike could stem from either a misconfigured paid UA campaign or an organic viral social media burst. |
| **4. Addressable Lost Revenue (`$35,752` / 27d)** | `27,073` incompatible sessions $\times$ `9.65%` Compatible CR (`2,612` buyers) $\times$ `$14.1615` ARPPU $- \$1,238.19 = \$35,751.65$ (`$35,747.25` unrounded; `~$483k/yr`). | Represents the theoretical upper-bound revenue gap attributable to Android hardware incompatibility. | **Upper-Bound Assumption:** Non-eSIM Android devices are typically budget/older models whose owners have lower purchasing power than flagship Android users; actual realizable conversion would be lower than `9.65%`. |
| **5. Paid CAC Bleed (`-$39k` to `-$66k` — H4)** | `27,073` incompatible sessions generated only `$1,238.19` in gross billings (`$0.046` revenue per session). | Any paid acquisition spend directed at non-eSIM devices yields near-zero return (`-97%` ROAS at `$1.50` blended CAC). | **Sensitivity Assumption:** The schema lacks paid vs. organic attribution (`utm_medium`) and actual CAC figures; dollar losses are modeled across simulated blended CAC tiers (`$0.75–$3.50`). |
| **6. In-Destination Purchases (`US->US`, `CA->CA`, `GB->GB`)** | `5,939` orders (`$82,100.94`, `22.89%` of revenue) have `geo_country` matching `transaction_plan_destination`. | Represents two high-value segments: (a) travelers purchasing eSIMs upon arrival (e.g., on airport Wi-Fi in the destination country) and (b) domestic users buying secondary/backup data SIMs. | Because `geo_country` reflects IP geolocation at session start, we cannot separate "already-landed international tourists on US airport Wi-Fi" from "US residents buying backup data" without `user_home_country` or SIM carrier MCC/MNC telemetry. |
| **7. Implied Promotional Concessions (`25.5%` iOS vs `21.1%` Android — H7)** | Realized `total_billings_in_usd` varies between `$0.99` and `MAX(price)` within identical `(destination, quota)` pairs. | Price realization below the maximum observed tier price reflects promotional vouchers, referral discounts, or `$0.99` intro hooks. | **Proxy Assumption:** Because `promo_code` and `currency` are not in the schema, price dispersion below `MAX(price)` is an *implied price concession* proxy sensitive to upper-tail outliers (e.g., `CA 10 GB`); `MODE(price)` is recommended in production. |

### 6.2. Verified Production SQL Inventory & Phase A Sign-Off
All Phase A empirical findings are 100% reproducible via four modular, deduplicated production SQL scripts:
1. [`sql/01_data_audit.sql`](file:///c:/Users/37067/OneDrive/Stalinis%20kompiuteris/kiti-projektai/Saily-ND/sql/01_data_audit.sql): DAMA 8-dimension data hygiene, session deduplication (`241,548` sessions), 3-metric CR reconciliation (`9.15%` / `10.12%` / `10.40%`), deduplicated cohort bounce rates (`70.78%` / `47.53%` / `50.98%`), `110` incompatible converting sessions bug, August 27 full 24h day completeness proof (Query 6), temporal continuity (`27/27` days), tag synchronization (`99.88%`), and double-firing loop audit (`250` sessions `>15` events).
2. [`sql/02_funnel_and_markov.sql`](file:///c:/Users/37067/OneDrive/Stalinis%20kompiuteris/kiti-projektai/Saily-ND/sql/02_funnel_and_markov.sql): 3-cohort 4-stage deduplicated funnel matrix, daily time-series conversion rates (including `daily_ex_morocco_cr_pct`), upper-bound Android opportunity sizing (`$35,751.65` / `$35,747.25` unrounded), Two-Proportion Z-test ($Z = 20.28$), and stochastic Markov transition & hazard matrices.
3. [`sql/03_anomalies_and_corridors.sql`](file:///c:/Users/37067/OneDrive/Stalinis%20kompiuteris/kiti-projektai/Saily-ND/sql/03_anomalies_and_corridors.sql): Dual-anomaly deconstruction (August 27 Morocco surge & destination intent; August 16 record peak & corridor/quota drivers), top 10 global revenue corridors, and Simpson's Paradox geographic tests across 11 markets.
4. [`sql/04_economics_and_behavior.sql`](file:///c:/Users/37067/OneDrive/Stalinis%20kompiuteris/kiti-projektai/Saily-ND/sql/04_economics_and_behavior.sql): Timestamp-free quota exploration (H5 test), unit economics ($/GB), implied price concession penetration & Android promo parity P&L simulation (`+$39k to +$134k/yr`), incompatible device CAC sensitivity matrix, day-of-week seasonality index, buyer archetypes, deduplicated search fatigue (`Golden 2–3 Event Window`), destination indecision (`1 vs 2 vs 3+ countries`), deterministic `EU <-> AT` cross-shopping (`3,078` sessions), and deduplicated checkout retry friction.

