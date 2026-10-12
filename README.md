# Saily Data Analyst Case Study Repository

**Candidate:** Mantas Normantas  
**Role Applied:** Data Analyst (Saily)  
**Organization:** Saily (Nord Security)  
**Architecture Framework:** **PACE (Plan $\to$ Analyze $\to$ Construct $\to$ Execute)**  
**Data Environment:** Google Cloud BigQuery (`homework-data2020.saily_data_analyst` / `homework-data2020.saily_data_analyst.sessions` & `events`, Aug 1 – Aug 27, 2024)  
**Verification Status:** 100% Reconciled & Audited across SQL, Python Notebooks, Visual Charts, and Executive Reports

---

## 1. Repository Architecture & Deliverable Index

| PACE Phase | Deliverable File / Directory | Purpose & Scope |
| :--- | :--- | :--- |
| **Phase P (Plan)** | [`PACE_MASTER_PLAN.md`](PACE_MASTER_PLAN.md) | Six-Pillar DAMA Data Hygiene Audit Protocol, SMART Objectives, Hypothesis Registry (`H1–H8`), Mathematical Formulations, and Epistemological Governance. |
| **Phase A (Analyze)** | [`PHASE_A_ANALYTICAL_FINDINGS.md`](PHASE_A_ANALYTICAL_FINDINGS.md) | Exhaustive 6-Part Empirical Report mirroring the 4 SQL modules (`241,548` deduplicated sessions, `24,456` converting sessions, `25,133` orders, `$358,625.85` gross billings). |
| **Phase A (SQL Suite)** | [`sql/01_data_audit.sql`](sql/01_data_audit.sql)<br>[`sql/02_funnel_and_markov.sql`](sql/02_funnel_and_markov.sql)<br>[`sql/03_anomalies_and_corridors.sql`](sql/03_anomalies_and_corridors.sql)<br>[`sql/04_economics_and_behavior.sql`](sql/04_economics_and_behavior.sql) | Production BigQuery SQL scripts with deduplicated CTE architecture (`1` row per `unique_session_id` before joining `events`, while preserving multi-order session revenue). |
| **Phase C (Construct)** | [`PHASE_C_VISUAL_SYNTHESIS_AND_DECISION_MATRIX.md`](PHASE_C_VISUAL_SYNTHESIS_AND_DECISION_MATRIX.md) | Complete Visual Atlas (embedding all 8 charts), 7-Initiative `P0–P2` Impact vs. Effort Decision Matrix, and Telemetry v2 + `dbt` Data Engineering Specification. |
| **Phase C (Visual Gallery)** | [`figures/`](figures/) (`8` 300-DPI PNG charts) | `01_data_hygiene_and_bounce.png`, `funnel_comparison.png`, `anomaly_timeseries.png`, `04_corridors_archetypes_simpson.png`, `05_behavioral_fatigue_and_indecision.png`, `plan_migration_matrix.png`, `lost_revenue_waterfall.png`, `07_unit_economics_and_promo_parity.png`. |
| **Phase C (Notebooks)** | [`notebooks/`](notebooks/) (`01` to `04` `.ipynb`) | Modular, pre-executed Jupyter Notebooks (`01_data_audit.ipynb`, `02_funnel_and_markov.ipynb`, `03_anomalies_and_corridors.ipynb`, `04_economics_and_behavior.ipynb`). |
| **Phase E (Presentation Decks)** | [`Saily_Executive_Presentation_Mantas_Normantas.pptx`](Saily_Executive_Presentation_Mantas_Normantas.pptx)<br>[`Saily_Executive_Presentation_Mantas_Normantas.pdf`](Saily_Executive_Presentation_Mantas_Normantas.pdf)<br>[`Saily_Executive_Presentation_Mantas_Normantas.html`](Saily_Executive_Presentation_Mantas_Normantas.html) | 12-Slide Widescreen (16:9) Executive Presentation (`Part I: Core Executive Deck [Slides 1–7]` + `Part II: Technical Deep-Dive Appendix [Slides 8–12]`) with Speaker Notes in `.pptx`, `.pdf`, and interactive `.html`. |
| **Phase E (Storyboard & Q&A)** | [`EXECUTIVE_PRESENTATION_DECK.md`](EXECUTIVE_PRESENTATION_DECK.md) | Executive Storyboard + **Part III: Live Interview Defense Playbook (10 Tough Bar-Raiser Q&As)**. |

---

## 2. Executive Summary of Verified Findings (`H1–H8`)

1. **Primary Key Deduplication & Three Conversion Rate Definitions (`Module 1`):**
   - `homework-data2020.saily_data_analyst.sessions` contains `274,695` raw rows but **`241,548` distinct `unique_session_id`s** (`30,836` duplicated session IDs generating `33,147` surplus rows).
   - `transaction_id` (`25,133` valid paid orders totaling **`$358,625.85`**, `$14.27` AOV) is 100% unique across **`24,456` converting sessions** (`677` multi-plan orders within the same session; `$14.66` ARPPU).
   - **Strict Deduplicated Session CR = `10.12%`** (`24,456 / 241,548`) vs. **Order-to-Session Ratio = `10.40%`** (`25,133 / 241,548`) vs. **Naive Row Ratio = `9.15%`** (`25,133 / 274,695`).
2. **Multi-Cohort Funnel & Stochastic Markov Drop Hazard (`Module 2` — `H1` & `H2` Confirmed):**
   - **iOS (`12.48%` CR)** outperforms **Android Compatible (`9.65%` CR)** by **`+2.84 pp` unrounded (`+2.83 pp` rounded, $Z = 20.28, p < 0.0001$)**. Compatible Android actually beats iOS at initial plan selection (`S0 -> S1`: `52.18%` vs. `48.52%`), but suffers a dual bottleneck at **`S1 -> S2` Plan Configuration (`43.42%` vs. `30.58%` drop)** and **`S2 -> S3` Payment (`67.32%` vs. `62.94%` drop)**.
   - **Android Incompatible (`0.41%` CR):** `70.78%` (`19,162 / 27,073`) bounce with zero events, `7,889` select a plan (`S1`), **`4,735` reach `click_to_order_2` (`S2`, `97.68%` terminal drop hazard)**, and **`110` sessions (`111` orders, `$1,238.19`) still pay** for an unusable eSIM.
3. **Macro Anomalies, Weekly Seasonality & Simpson's Paradox (`Module 3` — `H3` Confirmed, `H6` Rejected):**
   - **Aug 27 Morocco Viral Domestic Surge (`H3`):** `5,134` Moroccan (`MA`) iOS sessions (`50.79%` of global iOS traffic that day) converted at **`0.10%`** (`5` buyers), with `97.8%` (`5,019 / 5,134` logged event pairs across all `5,787` Moroccan sessions) searching for local `MA` data. Excluding Morocco restores Aug 27 iOS CR from **`5.64%` to `11.36%`** (`565 / 4,975`).
   - **Weekly Seasonality & Archetypes:** **Fridays (`1.083x` index, `11.10%` CR — peaking on Aug 16 with `1,130` orders / `$16,240.64`)** and **Saturdays (`1.074x` index, `10.89%` CR)** lead conversion and booking volume; **Wednesdays (`0.922x` index, `833.0` buyers/day)** mark the trough. In-Destination Purchases (`geo_country = destination`) generate **`22.89%` (`$82,100.94`)** of global revenue, and iOS leads Compatible Android in **10 of the top 11 markets** (`H6` rejected).
4. **Behavioral Navigation, Quota Matrix, Promo Parity & CAC Bleed (`Module 4` — `H4, H7, H8` Confirmed, `H5` Rejected):**
   - **Golden `2–3` Event Window & Indecision (`H8`):** **`92.57%` (`22,638 / 24,456`)** of buyers convert in `2–3` events (`30.37%` CR). Browsing `3+` countries collapses CR by **`-72.3%`** (`24.11% -> 6.69%`), and **`12.59%` (`3,078`)** of buyers cross-shopped destinations (led by **`EU <-> AT`: `693` sessions / `22.51%`**).
   - **Quota Exploration Matrix (`H5` Rejected):** **`97.12%` (`23,723 / 24,426`)** of buyers purchase their maximum browsed quota (`92.16%` single-quota + `4.96%` multi-quota largest vs. `2.88%` off-diagonal).
   - **Promo Asymmetry (`H7`) & Paid CAC Bleed (`H4`):** **`25.50%`** of iOS orders receive below-anchor promo pricing vs. **`21.07%`** on Compatible Android (`+4.43 pp` gap $\implies$ **`+$39k–$134k/yr`** Android parity upside). Upper-bound hardware opportunity equals **`+$35,751.65` over 27d (`~$483.3k/yr` ceiling)**, while acquiring `27,073` incompatible sessions at `$1.50` blended CAC burns **`-$39,371.31` net over 27d (`-$532k/yr`)**.
