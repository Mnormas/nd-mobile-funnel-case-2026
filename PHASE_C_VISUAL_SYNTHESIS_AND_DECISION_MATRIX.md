# Saily Data Analyst Case Study: Phase C Visual Synthesis, Decision Matrix & Telemetry v2 Specification

**Document Type:** Visual Synthesis, Prioritized Decision Matrix & Telemetry Engineering Specification (Deliverable C)  
**Candidate:** Mantas Normantas  
**Role Applied:** Data Analyst (Saily)  
**Organization:** Saily (Nord Security)  
**Evaluation Date:** October 2026  
**Data Environment:** Google Cloud BigQuery (`homework-data2020.saily_data_analyst`)  
**Companion Deliverables:** [`PACE_MASTER_PLAN.md`](file:///c:/Users/37067/OneDrive/Stalinis%20kompiuteris/kiti-projektai/Saily-ND/PACE_MASTER_PLAN.md) | [`PHASE_A_ANALYTICAL_FINDINGS.md`](file:///c:/Users/37067/OneDrive/Stalinis%20kompiuteris/kiti-projektai/Saily-ND/PHASE_A_ANALYTICAL_FINDINGS.md) | [`sql/01–04`](file:///c:/Users/37067/OneDrive/Stalinis%20kompiuteris/kiti-projektai/Saily-ND/sql/) | [`notebooks/01–04`](file:///c:/Users/37067/OneDrive/Stalinis%20kompiuteris/kiti-projektai/Saily-ND/notebooks/)

---

## 1. Executive Purpose of Phase C (Construct)

In the **PACE (Plan, Analyze, Construct, Execute)** lifecycle, **Phase C (Construct)** transforms verified statistical and SQL outputs from Phase A into **visual artifacts, reproducible computational notebooks, prioritized commercial decision models, and engineering specifications**:

| Phase A Analytical Module | Phase C Visual Artifact(s) (`figures/`) | Phase C Reproducible Notebook (`notebooks/`) | Hypotheses & Decisions Covered |
| :--- | :--- | :--- | :--- |
| **Module 1: Six-Pillar DAMA Data Hygiene Audit** ([`01_data_audit.sql`](file:///c:/Users/37067/OneDrive/Stalinis%20kompiuteris/kiti-projektai/Saily-ND/sql/01_data_audit.sql)) | [`01_data_hygiene_and_bounce.png`](file:///c:/Users/37067/OneDrive/Stalinis%20kompiuteris/kiti-projektai/Saily-ND/figures/01_data_hygiene_and_bounce.png) | [`01_data_audit.ipynb`](file:///c:/Users/37067/OneDrive/Stalinis%20kompiuteris/kiti-projektai/Saily-ND/notebooks/01_data_audit.ipynb) | Session deduplication (`241,548` vs. `274,695` rows), 3 CR definitions (`9.15%` / `10.12%` / `10.40%`), zero-event bounce (`70.78%` Android Incompat). |
| **Module 2: Funnel, Markov Hazard & Checkout Retries** ([`02_funnel_and_markov.sql`](file:///c:/Users/37067/OneDrive/Stalinis%20kompiuteris/kiti-projektai/Saily-ND/sql/02_funnel_and_markov.sql)) | [`funnel_comparison.png`](file:///c:/Users/37067/OneDrive/Stalinis%20kompiuteris/kiti-projektai/Saily-ND/figures/funnel_comparison.png) | [`02_funnel_and_markov.ipynb`](file:///c:/Users/37067/OneDrive/Stalinis%20kompiuteris/kiti-projektai/Saily-ND/notebooks/02_funnel_and_markov.ipynb) | **`H1` Confirmed** (`Z = 20.28`, `+2.84 pp` iOS lead; Android dual bottleneck at `S1 -> S2` & `S2 -> S3`), **`H2` Confirmed** (`97.68%` terminal wall, `110` bug buyers). |
| **Module 3: Macro Anomalies, Seasonality, Corridors & Simpson's Paradox** ([`03_anomalies_and_corridors.sql`](file:///c:/Users/37067/OneDrive/Stalinis%20kompiuteris/kiti-projektai/Saily-ND/sql/03_anomalies_and_corridors.sql)) | [`anomaly_timeseries.png`](file:///c:/Users/37067/OneDrive/Stalinis%20kompiuteris/kiti-projektai/Saily-ND/figures/anomaly_timeseries.png), [`04_corridors_archetypes_simpson.png`](file:///c:/Users/37067/OneDrive/Stalinis%20kompiuteris/kiti-projektai/Saily-ND/figures/04_corridors_archetypes_simpson.png) | [`03_anomalies_and_corridors.ipynb`](file:///c:/Users/37067/OneDrive/Stalinis%20kompiuteris/kiti-projektai/Saily-ND/notebooks/03_anomalies_and_corridors.ipynb) | **`H3` Confirmed** (Aug 27 Morocco `5,134` iOS surge; `11.36%` ex-MA CR), Fri/Sat seasonality (`1.083x` / `1.074x`), In-Destination (`22.89%` rev), **`H6` Rejected** (10/11 markets). |
| **Module 4: Behavioral Navigation, Quota Matrix, Unit Economics & CAC Bleed** ([`04_economics_and_behavior.sql`](file:///c:/Users/37067/OneDrive/Stalinis%20kompiuteris/kiti-projektai/Saily-ND/sql/04_economics_and_behavior.sql)) | [`05_behavioral_fatigue_and_indecision.png`](file:///c:/Users/37067/OneDrive/Stalinis%20kompiuteris/kiti-projektai/Saily-ND/figures/05_behavioral_fatigue_and_indecision.png), [`plan_migration_matrix.png`](file:///c:/Users/37067/OneDrive/Stalinis%20kompiuteris/kiti-projektai/Saily-ND/figures/plan_migration_matrix.png), [`lost_revenue_waterfall.png`](file:///c:/Users/37067/OneDrive/Stalinis%20kompiuteris/kiti-projektai/Saily-ND/figures/lost_revenue_waterfall.png), [`07_unit_economics_and_promo_parity.png`](file:///c:/Users/37067/OneDrive/Stalinis%20kompiuteris/kiti-projektai/Saily-ND/figures/07_unit_economics_and_promo_parity.png) | [`04_economics_and_behavior.ipynb`](file:///c:/Users/37067/OneDrive/Stalinis%20kompiuteris/kiti-projektai/Saily-ND/notebooks/04_economics_and_behavior.ipynb) | **`H4` Confirmed** (`-$532k/yr` CAC bleed), **`H5` Rejected** (`97.12%` diagonal quota retention), **`H7` Confirmed** (`+4.43 pp` promo gap), **`H8` Confirmed** (`EU <-> AT` cross-shopping). |

---

## 2. Visual Synthesis Atlas (Modules 1 to 4)

### 2.1 Module 1 Visual: Primary Key Deduplication & Cohort Bounce Structure
![Module 1 Data Hygiene & Bounce](figures/01_data_hygiene_and_bounce.png)

* **Analytical Takeaway:** Collapsing `33,147` surplus duplicate session rows (`30,836` duplicated `unique_session_id`s) reveals that Saily's true deduplicated Session Conversion Rate is **`10.12%`** (`24,456 / 241,548`), **`+0.97 pp` (`+10.6%` relative) higher** than the naive row-level calculation (`9.15%`), while total order intensity stands at **`10.40%`** (`25,133` orders / `241,548` sessions).
* **Telemetry Blind Spot:** `51.98%` (`125,553 / 241,548`) of deduplicated sessions record zero events (`click_to_order_1` / `click_to_order_2`), peaking at **`70.78%` (`19,162 / 27,073`) on Android Incompatible** (`+23.25 pp` higher than Android Compatible's `47.53%`).

---

### 2.2 Module 2 Visual: Multi-Cohort Funnel & Stochastic Markov Drop Hazard (`H1` & `H2`)
![Module 2 Funnel & Markov Drop Hazard](figures/funnel_comparison.png)

* **Analytical Takeaway (`H1` Confirmed — Dual Bottleneck on Compatible Android):** Compatible Android actually **outperforms iOS at top-of-funnel plan selection (`S0 -> S1`: `52.18%` vs. `48.52%`, `+3.66 pp`)**. The entire **`2.84 pp` unrounded (`2.83 pp` rounded, $Z = 20.28, p < 0.0001$)** conversion deficit occurs in the lower funnel:
  1. **Primary Bottleneck (`S1 -> S2` Plan Configuration):** Compatible Android loses **`43.42%`** of engaged shoppers before checkout vs. **`30.58%`** on iOS (`+12.84 pp` excess drop hazard).
  2. **Secondary Bottleneck (`S2 -> S3` Payment Execution):** Compatible Android loses **`67.32%`** of checkout initiators vs. **`62.94%`** on iOS (`+4.38 pp` excess drop hazard).
* **Analytical Takeaway (`H2` Confirmed — Incompatible Android Terminal Wall):** `7,889` incompatible Android users select a plan (`S1`) and **`4,735` reach `click_to_order_2` (`S2`)**, where **`97.68%` (`4,625 / 4,735`) abandon** and **`110` sessions (`111` orders, `$1,238.19`) still pay** for an eSIM their hardware cannot install.

---

### 2.3 Module 3 Visuals: Macro Anomalies (`H3`), Weekly Cyclicality & Simpson's Paradox (`H6`)
![Module 3 Anomaly Time-Series & Seasonality](figures/anomaly_timeseries.png)
![Module 3 Corridors, Archetypes & Simpson's Paradox](figures/04_corridors_archetypes_simpson.png)

* **Analytical Takeaway (`H3` Confirmed — Aug 27 Morocco Viral Surge):** On Aug 27, `5,134` Moroccan (`MA`) iOS sessions (`50.79%` of global iOS traffic that day) flooded the app searching for local `MA` data (`97.8%` / `5,019` of `5,134` logged event pairs across all `5,787` Moroccan sessions) and converted at **`0.10%`** (`5` buyers). Removing Morocco restores Aug 27 iOS CR from **`5.64%` to `11.36%`** (`565 / 4,975`), proving the crash was an external composition shock rather than an iOS bug.
* **Weekly Demand Cyclicality:** Across the 27-day window (led by the **Aug 16 peak: `1,130` orders / `$16,240.64`**), **Fridays (`1.083x` index, `11.10%` CR)** and **Saturdays (`1.074x` index, `10.89%` CR)** represent the weekly conversion and booking peaks, while **Wednesdays (`0.922x` index, `833.0` buyers/day)** represent the weekly trough.
* **Buyer Archetypes & Simpson's Paradox (`H6` Rejected):** In-Destination Purchases (`geo_country = destination`, e.g., Airport Wi-Fi / Local Backup SIMs) generate **`22.89%` (`$82,100.94`, `5,939` orders)** of global billings, while Long-Haul Transatlantic trips command a **`+25.0%` AOV premium (`$17.28`)**. Country-by-country stratification proves iOS outperforms Compatible Android in **10 of the top 11 markets**, rejecting `H6`.

---

### 2.4 Module 4 Visuals: Behavioral Navigation (`H8`), Quota Exploration (`H5`), Hardware & CAC Waterfall (`H4`) & Unit Economics (`H7`)
![Module 4 Behavioral Navigation & Retries](figures/05_behavioral_fatigue_and_indecision.png)
![Module 4 Quota Exploration Matrix](figures/plan_migration_matrix.png)
![Module 4 Lost Revenue Waterfall & CAC Bleed](figures/lost_revenue_waterfall.png)
![Module 4 Unit Economics & Promo Parity](figures/07_unit_economics_and_promo_parity.png)

* **Golden 2–3 Event Window & Indecision Cliff (`H8` Confirmed):** **`92.57%` (`22,638 / 24,456`)** of all conversions happen within exactly **`2–3` events (`30.37%` CR)**. Users browsing `3+` countries suffer a **`-72.3%` conversion collapse** (`24.11%` $\to$ `6.69%`). Among converting sessions, **`12.59%` (`3,078 / 24,456`)** cross-shopped an alternative destination — led by **`EU <-> AT` (`693` sessions / `22.51%`)**, where European travelers compare regional `EU` vs. single-country `AT` plans (`$16.65` vs. `$9.79` for 5 GB).
* **Checkout Retry Loops (`click_to_order_2`):** While `1` attempt converts at `37.47%` on iOS and `32.22%` on Compatible Android, **`3+` attempts cause iOS conversion to plunge `-52.18%` to `17.92%` (`132 / 736`)**, diagnosing severe Apple Pay / 3DS / token-timeout friction.
* **Quota Exploration Matrix (`H5` Rejected):** Across `24,426` converting sessions with event telemetry, **`92.16%` (`22,512`)** viewed only a single quota tier, and **`4.96%` (`1,211`)** explored multiple quotas and bought the **largest** quota viewed (**`97.12%` / `23,723` on the diagonal** vs. only **`2.88%` / `703` off-diagonal**).
* **Hardware Opportunity Ceiling & Paid CAC Bleed (`H4` Confirmed):** Upper-bound hardware parity on `27,073` incompatible sessions represents **`+$35,751.65` net over 27 days (`~$483,300/yr` ceiling)**. In reality, acquiring `27,073` incompatible sessions at a `$1.50` blended CAC (`$3.00` Paid CPA at 50% paid share) burns **`-$39,371.31` net over 27 days (`-$532k/yr`)**.
* **Unit Economics (`$/GB`) & Implied Promo Parity (`H7` Confirmed):** `10 GB` plans offer a `39%` (`US`) to `56%` (`TR`) lower cost per GB than `1 GB` plans. Modal price decomposition across `24,782` orders (`98.6%` of volume) proves **`25.50%` of iOS orders receive below-anchor promo pricing vs. `21.07%` on Compatible Android (`+4.43 pp` iOS promo advantage)**, yielding **`+$39k` to `+$134k/yr`** in Android parity upside.

---

## 3. Comprehensive 7-Initiative Impact vs. Effort Decision Matrix (`P0–P2`)

Every recommendation below is anchored directly to a confirmed Phase A finding (`H1–H8`), a specific SQL verification query (`sql/01–04`), and an explicit financial P&L or engineering KPI:

| Priority & ID | Strategic Initiative | Analytical Root Cause (`Phase A` Evidence) | Product / Marketing / Engineering Intervention | Quantified 27-Day Impact | Annualized P&L Impact (`365/27`) | Effort & Owner | Target KPI |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`P0-1`** | **Pre-Install Paid UA Hardware Exclusion & Play Store `euicc` Catalog Gate** | **`H4` Confirmed:** `27,073` incompatible Android sessions (`70.78%` bounce, `0.41%` CR) waste UA spend across 27 days. | **1.** Enable `<uses-feature android:name="android.hardware.telephony.euicc"/>` device-catalog filtering in Google Play Console.<br>**2.** Exclude non-eSIM OEM device models in Google App Campaigns (UAC), Meta, and TikTok. | Saves **`+$19,067` to `+$93,517`** in wasted UA spend (**`+$39,371`** base case at `$1.50` blended CAC). | **`+$258k` to `+$1.26M/yr`** (**`+$532k/yr`** base case marketing savings). | **Low** (1–2 days)<br>*Perf. Marketing & Android Release Eng.* | Reduce incompatible session share from **`11.21%` to `<1.50%`**. |
| **`P0-2`** | **In-App Pre-Checkout Hardware Gate (`S0` Modal + `S2` Hard Block)** | **`H2` Confirmed:** `7,889` incompatible sessions reach `S1`, `4,735` reach `S2` (`97.68%` drop), and **`110` sessions (`111` orders, `$1,238.19`) pay** for an unusable eSIM. | **1.** Trigger `EuiccManager.isEnabled()` check at app open (`S0`) and disable `click_to_order_2` (`S2`) for `esim_compatible = 'false'`.<br>**2.** Offer **"Share / Buy for a Compatible Companion Device"** flow with explicit hardware attestation checkbox. | Eliminates **`110` defective sessions (`111` orders / `$1,238.19`)** in chargebacks & support tickets (`~$15/ticket`). | Eliminates **`~1,500` defective orders/yr** (`~$16.7k` refunds + `~$22.5k` CS load). | **Low** (3–5 days)<br>*Android Mobile Eng. & Product* | Incompatible `S2` reach **`4,735 -> 0`**; accidental purchases **`110 -> 0`**. |
| **`P1-1`** | **Compatible Android Plan-Config (`S1 -> S2`) UX & Promo Parity** | **`H1` & `H7` Confirmed:** Compatible Android suffers **`43.42%` `S1 -> S2` drop** (vs. `30.58%` iOS) and a **`-4.43 pp` implied promo gap** (`21.07%` vs. `25.50%` iOS). | **1.** Surface explicit `$/GB` savings badges (`Save 39%–56%/GB on 10 GB`) on `S1` plan cards.<br>**2.** Deploy auto-applied promo deeplink parity on Android (`+$0.50` concession on incremental orders) and streamline `S1 -> S2` into a sticky bottom sheet. | **Conservative (`+0.60 pp` CR):** `+514` buyers / **`+$2,888`** net.<br>**Optimistic (`+1.20 pp` CR):** `+1,027` buyers / **`+$9,905`** net. | **`+$39,041/yr` to `+$133,899/yr`** net incremental gross billings. | **Medium** (2 sprints)<br>*Product Growth & Android UX* | Reduce Android `S1 -> S2` drop from **`43.42%` toward `<35.0%`**; lift CR from **`9.65%` to `10.25%–10.85%`**. |
| **`P1-2`** | **Checkout Retry Loop Recovery (`click_to_order_2` Fallback Sheet)** | **Module 2.3 Confirmed:** iOS `S2 -> S3` CR drops **`-52.18%`** (`37.47% -> 17.92%`) on `3+` `click_to_order_2` attempts (`736` iOS + `496` Android Compat sessions). | Detect a 2nd consecutive `click_to_order_2` tap within the same session without `transaction_id` creation and auto-trigger a frictionless **1-Tap Payment Fallback Sheet** (switching Apple Pay / Google Pay $\leftrightarrow$ Express Card / PayPal). | Recovers `~25%–35%` of stalled `2+` attempt sessions (`~450–650` buyers $\times$ `$14.66` ARPPU = **`+$6,600` to `+$9,500`**). | **`+$89k` to `+$128k/yr`** in recovered high-intent checkout billings. | **Medium** (1–2 sprints)<br>*Payments & Checkout Eng.* | Lift `3+` attempt checkout CR on iOS from **`17.92%` to `>28.0%`**. |
| **`P1-3`** | **Paid UA Geo-Guardrails & Viral Domestic Anomaly Circuit-Breaker** | **`H3` Confirmed:** Aug 27 Morocco surge (`5,134` iOS sessions, `0.10%` CR, `97.8%` domestic `MA` search) diluted global iOS CR by `-5.72 pp`. | **1.** Add automated Paid UA anomaly circuit-breaker pausing ad sets when any single country exceeds `3x` trailing 7-day session volume with `<1.0%` CR.<br>**2.** Show an in-app banner when `geo_country == destination` in non-destination domestic markets clarifying Saily is a travel eSIM. | Prevents domestic viral traffic spikes from distorting automated CPA bidding algorithms and executive KPI dashboards. | Protects Paid UA ROAS & executive reporting integrity across 200+ markets. | **Low** (1 sprint)<br>*Marketing Analytics & BI* | Maintain `Ex-Anomaly CR` alongside `Observed Global CR` in Looker/Tableau. |
| **`P2-1`** | **Regional vs. Single-Country Smart Bundle Card (`EU <-> AT` Cross-Shop)** | **`H8` Confirmed:** `3,078` buyers (`12.59%`) cross-shopped destinations (`#1 EU <-> AT`: `693` buyers / `22.51%`); `3+` countries collapses CR by **`-72.3%`** (`24.11% -> 6.69%`). | When a user searches `2+` countries in the same region (or compares `EU` vs. an EU member state like `AT`), display a **"Visiting 2+ European Countries? Compare Regional EU (`$16.65`) vs. Single-Country (`$9.79`)"** decision helper within the **Golden `2–3` Event Window**. | Lifts multi-country (`24,878` sessions) conversion by `+1.5 to +2.5 pp` (`+373` to `+622` buyers = **`+$5,400` to `+$9,100`**). | **`+$73k` to `+$123k/yr`** in rescued multi-destination bookings + higher regional AOV. | **Medium** (2 sprints)<br>*Search & Discovery Squad* | Lift `2+` country engaged CR from **`9.88%` (`2,457 / 24,878`) to `>12.0%`**. |
| **`P2-2`** | **Thu–Sat Peak Weekend Getaway Bidding & Transatlantic `10 GB` Anchoring** | **Module 3.2 & 3.4 Confirmed:** Fri (`1.083x`, `11.10%` CR) and Sat (`1.074x`, `10.89%` CR) peak; Transatlantic (`US/CA -> Europe`) commands `$17.28` AOV (`+25%`). | **1.** Shift Paid UA budget pacing `+15%` into Thu PM–Sat AM to capture high-CR weekend departures.<br>**2.** Default `US/CA -> Europe/UK` corridors to the **`10 GB` (`$2.24–$3.08/GB`)** anchor tier (`97.12%` of buyers purchase their max viewed quota). | Captures **`+3% to +5%` AOV expansion** on transatlantic & regional corridors (**`+$4,500` to `+$7,500`** over 27d). | **`+$61k` to `+$101k/yr`** in incremental AOV & ad-spend efficiency. | **Low** (1 sprint)<br>*Growth Marketing & Pricing* | Lift global AOV from **`$14.27` toward `$14.85+`**. |

---

## 4. Telemetry v2 & Data Warehouse Engineering Specification

To permanently resolve the six structural limitations uncovered during our **Module 1 DAMA Data Audit** ([`sql/01_data_audit.sql`](file:///c:/Users/37067/OneDrive/Stalinis%20kompiuteris/kiti-projektai/Saily-ND/sql/01_data_audit.sql)) and **Phase A Section 6 Epistemological Governance** ([`PHASE_A_ANALYTICAL_FINDINGS.md`](file:///c:/Users/37067/OneDrive/Stalinis%20kompiuteris/kiti-projektai/Saily-ND/PHASE_A_ANALYTICAL_FINDINGS.md#L401-L429)), Data Engineering and Mobile SDK teams should deploy the following **Telemetry v2 Schema Upgrade**:

### 4.1 Schema & Event Pipeline Upgrades (`sessions` & `events`)

| Limitation Identified in Phase A | Current v1 Schema Behavior | Proposed Telemetry v2 Engineering Specification | Analytical & Business Value Unlocked |
| :--- | :--- | :--- | :--- |
| **1. Non-Unique `unique_session_id` (`30,836` duplicate IDs / `33,147` surplus rows)** | `sessions` logs multiple rows per `unique_session_id` (both multi-plan orders and duplicate non-converting emission rows), inflating naive row denominators by `+13.7%`. | Split `sessions` into two strict, primary-keyed tables:<br>1. `fct_sessions` (1 row per `unique_session_id`, PK enforced).<br>2. `fct_orders` (1 row per `transaction_id`, FK `unique_session_id`). | Eliminates `-0.97 pp` naive conversion rate distortion (`9.15%` vs. `10.12%`) while preserving all `25,133` orders (`$358,625.85`). |
| **2. Zero-Event Visibility Gap (`125,553` bounced sessions / `51.98%`)** | `events` only logs `click_to_order_1` and `click_to_order_2`, leaving `125,553` bounced sessions (`70.78%` of Android Incompatible) completely dark. | Add 4 top-of-funnel SDK events to `events`:<br>- `app_open`<br>- `compatibility_modal_shown` (`euicc_status: bool`)<br>- `destination_search` (`query_country`)<br>- `plan_card_impression` | Separates immediate splash-screen crashes, hardware incompatibility blocks, and catalog-price bounces. |
| **3. Missing Event Sequence Timestamps (`event_timestamp`)** | `events` lacks an intra-session timestamp or sequence counter (`seq_num`), preventing chronological path ordering (`10 GB -> 1 GB` vs. `1 GB -> 10 GB`). | Add `event_timestamp TIMESTAMP` (millisecond UTC precision) and `event_seq_id INT64` (`1, 2, 3...`) to every row in `homework-data2020.saily_data_analyst.events`. | Enables exact time-to-checkout latency analysis, directional down-sell vs. up-sell pathing, and session duration tracking. |
| **4. Client-Side Event Loop Spam (`250` sessions firing `>15` identical events, max `167`)** | Unthrottled UI button taps emit up to `167` duplicate rows for the same `(unique_session_id, event_name, destination, plan_quota)`. | Implement a **500ms client-side SDK debounce** on `click_to_order_1` and `click_to_order_2` and log `payment_error_code` (`apple_pay_cancel`, `3ds_timeout`, `card_declined`). | Prevents event-volume inflation and pinpoints why `3+` `click_to_order_2` retries on iOS suffer a `-52.18%` conversion collapse (`17.92%` CR). |
| **5. Missing Persistent User Identity (`user_id` / `device_id`)** | Only session-level `unique_session_id` is exposed; cross-session return journeys (`browse on Mon -> buy on Fri`) cannot be linked. | Add hashed `user_id STRING` and `device_advertising_id STRING` (IDFA / GAID / Firebase App Instance ID) to `fct_sessions`. | Quantifies multi-session consideration cycles, customer lifetime value (LTV), and repeat travel cohort retention. |
| **6. Unlogged List Price, Promo Code & Paid UA Attribution** | Discounts must be inferred via modal SKU anchor prices (`25.50%` iOS vs. `21.07%` Android), and Paid CAC bleed must be modeled via sensitivity bounds (`$0.75–$3.50`). | Add `list_price_usd`, `discount_amount_usd`, `promo_code_id` to `fct_orders`, and `acquisition_channel` (`paid_search`, `paid_social`, `organic`, `referral`) + `ad_cost_usd` to `fct_sessions`. | Enables exact promo elasticity measurement (`H7`) and real-time ROAS / wasted Paid CAC monitoring (`H4`). |

---

### 4.2 Production `dbt` Mart Pattern (`mart_saily_sessions_deduped.sql`)

Until Telemetry v2 is deployed in mobile clients, all BI dashboards (Looker / Tableau) should query the standardized deduplicated session mart defined in [`sql/01_data_audit.sql`](file:///c:/Users/37067/OneDrive/Stalinis%20kompiuteris/kiti-projektai/Saily-ND/sql/01_data_audit.sql#L140-L162):

```sql
-- Standardized dbt Mart Model: mart_saily_sessions_deduped
WITH sessions_deduped AS (
    SELECT
        unique_session_id,
        MIN(DATE(session_start_timestamp)) AS session_date,
        MAX(CASE WHEN device = 'iOS' THEN 'iOS' ELSE 'Android' END) AS os_family,
        MAX(esim_compatible) AS esim_compatible,
        ARRAY_AGG(geo_country IGNORE NULLS ORDER BY session_start_timestamp ASC LIMIT 1)[SAFE_OFFSET(0)] AS primary_geo_country,
        MAX(CASE WHEN transaction_id IS NOT NULL THEN 1 ELSE 0 END) AS is_converted_session,
        COUNT(DISTINCT transaction_id) AS total_orders_in_session,
        COALESCE(SUM(CASE WHEN transaction_id IS NOT NULL THEN total_billings_in_usd ELSE 0 END), 0.0) AS session_revenue_usd
    FROM `homework-data2020.saily_data_analyst.sessions`
    GROUP BY unique_session_id
),
events_agg AS (
    SELECT
        unique_session_id,
        COUNT(*) AS total_events,
        MAX(CASE WHEN event_name = 'click_to_order_1' THEN 1 ELSE 0 END) AS reached_step_1,
        MAX(CASE WHEN event_name = 'click_to_order_2' THEN 1 ELSE 0 END) AS reached_step_2,
        COUNTIF(event_name = 'click_to_order_2') AS checkout_attempts,
        COUNT(DISTINCT destination) AS distinct_countries_browsed,
        MAX(plan_quota) AS max_browsed_quota_gb
    FROM `homework-data2020.saily_data_analyst.events`
    GROUP BY unique_session_id
)
SELECT
    s.*,
    COALESCE(e.total_events, 0) AS total_events,
    COALESCE(e.reached_step_1, 0) AS reached_step_1,
    COALESCE(e.reached_step_2, 0) AS reached_step_2,
    COALESCE(e.checkout_attempts, 0) AS checkout_attempts,
    COALESCE(e.distinct_countries_browsed, 0) AS distinct_countries_browsed,
    e.max_browsed_quota_gb
FROM sessions_deduped s
LEFT JOIN events_agg e USING (unique_session_id);
```
