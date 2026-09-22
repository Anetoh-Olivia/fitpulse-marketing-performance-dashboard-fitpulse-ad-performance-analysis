# FitPulse Marketing Performance Analysis

*A performance analytics deep-dive into FitPulse, a direct-to-consumer fitness brand, tracing why ad spend kept climbing for two years while true profitability quietly eroded beneath a healthy-looking ROAS.*

---

## Description

FitPulse is a direct-to-consumer fitness brand selling 8 products online: Whey Protein, Creatine, Pre-Workout, Protein Bars, Resistance Bands, Foam Roller, Dumbbells, and Yoga Mat, running paid advertising across four platforms: Meta, TikTok, YouTube, and Google.

This project builds an end-to-end marketing analytics pipeline, from raw campaign data through PostgreSQL cleaning and normalization to a 6-page interactive Power BI dashboard, to diagnose what is really happening beneath the surface of FitPulse's ad performance.

This repository documents the Performance side of the analysis (the "are we reaching, engaging, and converting the right people?" story). A companion Profitability analysis, built on the same dataset but focused on margin, contribution, and true net profit, will follow separately.

---


Eighteen months into a spending increase, the marketing team at FitPulse is still reporting strong numbers. Impressions are up. Reach is up. Return on ad spend still shows green in every dashboard export. So why does it feel like the harder the team pushes, the less ground gets covered?

This project sets out to find the answer, not by assuming it, but by building the pipeline needed to actually see what the data says.

---

## Table of Contents

1. [Description](#description)
2. [Opening Hook](#opening-hook)
3. [Project Overview](#project-overview)
4. [Business Problem](#business-problem)
5. [Tools and Technologies](#tools-and-technologies)
6. [Skills Explored](#skills-explored)
7. [Dataset Description](#dataset-description)
   - [Data Dictionary, All 44 Columns](#data-dictionary-all-44-columns)
8. [Data Cleaning Process](#data-cleaning-process)
9. [Database Normalization and Views](#database-normalization-and-views)
10. [KPIs and Why They Were Chosen](#kpis-and-why-they-were-chosen)
11. [Dashboard Pages](#dashboard-pages)
    - [Page 1: Executive Summary](#page-1-executive-summary)
    - [Page 2: Awareness](#page-2-awareness)
    - [Page 3: Attention](#page-3-attention)
    - [Page 4: Interest and Conversion](#page-4-interest-and-conversion)
    - [Page 5: Efficiency](#page-5-efficiency)
    - [Page 6: Decision Center](#page-6-decision-center)
12. [Overall Key Findings](#overall-key-findings)
13. [Recommendations](#recommendations)
14. [Caveats and Limitations](#caveats-and-limitations)
15. [How to Explore](#how-to-explore)
16. [Author and Contact](#author-and-contact)

---

## Project Overview

The goal of this project was to build a complete, reproducible marketing analytics workflow: generate a realistic campaign dataset, clean and normalize it in a relational database, write diagnostic SQL across the full marketing funnel, and surface the findings in an interactive, filterable Power BI dashboard, the kind of tool a real marketing analyst would hand to leadership to answer hard questions about where spend is working and where it is not.

The analysis follows the marketing funnel end to end: Awareness, Attention, Interest, Conversion, Efficiency, and Decision, treating each stage as its own investigation with its own central question, rather than presenting a single flat performance summary.

<img width="1612" height="687" alt="fitpulse overview" src="https://github.com/user-attachments/assets/f532e4ea-af8e-426b-a95e-1d2502b74737" />

*Figure 1: Dashboard overview page.*

---

## Business Problem

FitPulse's marketing team was making decisions that looked right on the surface but were quietly damaging the business underneath. These are the specific problems this project was built to solve:

**1. The Scaling Trap**
The team was using ROAS alone to decide which ads to scale. An ad showing ROAS of 5 looked strong and worth scaling. But without comparing that ROAS to the breakeven ROAS of the specific product being advertised, nobody knew whether scaling would grow profits or accelerate losses.

**2. The Breakeven Illusion**
Every product has a different breakeven ROAS, the minimum return needed just to cover the cost of goods sold. For Dumbbells, that number is 6.67. An ad showing ROAS of 5.0 looks impressive to anyone who does not know the breakeven threshold, but that ad is losing money. The business was scaling campaigns based on ROAS numbers that looked healthy but were below breakeven. This is the illusion shock: high ROAS masking a profitability crisis.

Breakeven ROAS per product:

| Product | Breakeven ROAS |
|---|---|
| Dumbbells | 6.67 |
| Pre-Workout | 5.00 |
| Protein Bars | 5.00 |
| Whey Protein | 4.00 |
| Creatine | 4.00 |
| Foam Roller | 4.00 |
| Resistance Bands | 3.33 |
| Yoga Mat | 3.33 |

**3. Ad Fatigue Going Undetected**
Ads were running long past their effective lifespan. As frequency increased, the same audience kept seeing the same ad repeatedly. Hook rates, click-through rates, and ROAS were all declining, but there was no system to detect when a creative was dying versus when it was still worth scaling.

**4. Budget Misallocated Across Platforms**
Different platforms behave very differently. TikTok drives high click-through rates but low conversion rates because people click out of curiosity but rarely buy. Google drives lower CTR but much higher CVR because search intent means people are ready to purchase. Budget was not reflecting these behavioral differences.

**5. Attention Without Conversion**
Some creatives were generating strong engagement, high hook rates, high hold rates, but failing to drive purchases. High engagement was being mistaken for strong performance. Nobody was asking whether a creative was actually profitable at the individual creative level.

**6. Funnel Leakage Not Diagnosed**
The team could see impressions and purchases, but nobody was systematically diagnosing where the funnel was breaking down. Was it a traffic quality problem before the click, or a conversion experience problem after the click? The answer to that question leads to completely different solutions.

**7. Seasonal Spend Mismanagement**
Some products are seasonal. They perform strongly in specific quarters and generate losses in others. The team was spending on products year-round without understanding which quarters were genuinely profitable and which were draining the budget.

**8. Revenue vs Profit Confusion**
Q4 showed the highest gross revenue numbers and the team celebrated it as the best quarter. But Q4 also carried the highest fixed operational costs: warehouse, logistics, and peak-season staffing. When net profit was calculated, Q4 looked very different from what gross revenue suggested.

**9. No Creative Intelligence**
There was no systematic analysis of which hook types, creative angles, copy tones, ad formats, and UGC combinations drove the best outcomes. Creative decisions were being made on instinct rather than data.

**10. No Scalability Framework**
There was no decision framework for what to do with any given ad. Should it be scaled, monitored, optimised, or killed? Without a structured approach combining ROAS vs breakeven and fatigue status, every scaling decision was a guess.

---

## Tools and Technologies

| Tool | Purpose |
|---|---|
| PostgreSQL | Staging, cleaning, normalization, analytical queries, views |
| pgAdmin | SQL execution and database management |
| Power BI Desktop | Dashboard design, data modeling, DAX |
| DAX | KPI measures, month-over-month trend measures, conditional color logic |
| Python (pandas, numpy) | Synthetic dataset generation |
| Excel | Dataset staging and export format |

## Skills Explored

**SQL Data Cleaning**
Duplicate detection and removal, NULL auditing across all columns simultaneously (not one column at a time), categorical standardization, numeric range validation

**Database Normalization**
Splitting a flat table into 5 relational tables with surrogate keys and foreign key integrity

**Advanced SQL**
CTEs, window functions (LAG), HAVING filters for statistical significance, EXPLAIN ANALYZE for query optimization, targeted indexing on JOIN and WHERE columns

**View Design for BI Consumption**
Single source-of-truth master views for Power BI to connect to instead of querying raw tables

**DAX**
Time-intelligence measures (month-over-month), conditional formatting logic, IFERROR wrapping for months with no prior period data

**Power BI**
Multi-page dashboard design, cross-filtering, slicer-driven drill-down, bookmark-based insight toggles, insight-driven chart and page titles

**Business Analysis**
Funnel diagnostics, breakeven-vs-ROAS analysis, fatigue segmentation, budget reallocation reasoning

---

## Dataset Description

The dataset is a fully synthetic marketing performance dataset generated in Python (pandas and numpy) with a fixed seed for reproducibility, simulating two years (January 2023 to December 2024) of paid advertising activity for FitPulse across 4 platforms and 8 products.

- **Rows:** approximately 16,014 campaign records
- **Columns:** 38 original columns, plus 6 calculated columns added during SQL cleaning, making 44 columns total in the flat table
- **Platforms:** Meta, TikTok, YouTube, Google
- **Products:** Whey Protein, Creatine, Pre-Workout, Protein Bars, Resistance Bands, Foam Roller, Dumbbells, Yoga Mat

An intentional messiness layer was built into the dataset for realistic SQL cleaning practice: casing inconsistencies in platform and product names, campaign name suffixes (_v2, _test, _copy), approximately 1% duplicate rows (suffixed _dup), and NULL values in hook_rate and completion_rate.

<img width="1900" height="782" alt="fitpulse rawdataset" src="https://github.com/user-attachments/assets/9ac9d7c8-9997-4683-89df-63ea6236ab7c" />

### Data Dictionary, All 44 Columns

**Group 1: Identity and Creative (12 columns)**

| Column | Data Type | Description |
|---|---|---|
| row_id | VARCHAR(20) | Unique record identifier, Primary Key |
| date | DATE | Date the ad ran (2023-01-01 to 2024-12-31) |
| platform | VARCHAR(50) | Ad platform: Meta, TikTok, YouTube, Google |
| campaign_id | VARCHAR(20) | Unique campaign identifier |
| campaign_name | VARCHAR(100) | Format: Platform_Product_Date |
| ad_id | VARCHAR(20) | Creative identifier (CR-001 to CR-050) |
| product | VARCHAR(50) | One of 8 fitness products |
| hook_type | VARCHAR(50) | Question, Bold Statement, Story, Shock, Tutorial |
| creative_angle | VARCHAR(50) | Pain Point, Transformation, Social Proof, Educational, Lifestyle |
| copy_tone | VARCHAR(50) | Motivational, Clinical, Casual, Urgent, Empathetic |
| ad_format | VARCHAR(50) | Video, Image, Carousel, Story, Reel |
| has_ugc | INTEGER | User-generated content flag: 1 = Yes, 0 = No |

**Group 2: Product Economics (4 columns)**

| Column | Data Type | Description |
|---|---|---|
| selling_price | NUMERIC(10,2) | Product selling price in USD |
| product_cost | NUMERIC(10,2) | Cost of goods per unit in USD, never nulled |
| gross_margin_pct | NUMERIC(8,4) | (selling_price - product_cost) / selling_price |
| fixed_cost_allocation | NUMERIC(10,2) | Fixed operational cost per ad run, varies seasonally, never nulled |

**Group 3: Funnel Base and Fatigue (7 columns)**

| Column | Data Type | Description |
|---|---|---|
| impressions | INTEGER | Total times the ad was shown |
| reach | INTEGER | Unique people who saw the ad |
| frequency | NUMERIC(6,2) | Average times each person saw the ad (impressions / reach) |
| fatigue_score | NUMERIC(5,1) | Ad fatigue level: 0.5 (fresh) to 10.0 (burnt out) |
| frequency_at_fatigue | NUMERIC(6,2) | Frequency value at point of fatigue detection |
| creative_score | NUMERIC(5,1) | Creative quality score, falls as fatigue rises |
| hook_rate | NUMERIC(8,4) | Percentage of viewers who paused and engaged at the hook (max 0.40) |

**Group 4: Engagement and Spend (8 columns)**

| Column | Data Type | Description |
|---|---|---|
| hold_rate_3s | NUMERIC(8,4) | Percentage who stayed past 3 seconds, always below hook_rate |
| completion_rate | NUMERIC(8,4) | Percentage who watched to the end, always below hold_rate_3s |
| CPM | NUMERIC(10,4) | Cost per 1,000 impressions |
| spend | NUMERIC(10,2) | Total ad spend in USD |
| clicks | INTEGER | Total clicks on the ad |
| CTR | NUMERIC(8,4) | Click-through rate: clicks / impressions |
| CPC | NUMERIC(10,2) | Cost per click: spend / clicks |
| purchases | INTEGER | Total purchases generated by the ad |

**Group 5: Conversion and Revenue (7 columns)**

| Column | Data Type | Description |
|---|---|---|
| CVR | NUMERIC(8,4) | Conversion rate: purchases / clicks |
| CPA | NUMERIC(10,2) | Cost per acquisition, NULL when purchases = 0, never imputed |
| gross_revenue | NUMERIC(12,2) | Revenue before deductions: purchases x selling_price |
| discount_amount | NUMERIC(12,2) | Revenue lost to discounts (higher in Q4 promo season) |
| refund_amount | NUMERIC(12,2) | Revenue lost to refunds (product quality signal) |
| net_revenue | NUMERIC(12,2) | Revenue kept: gross minus discount minus refund |
| ROAS | NUMERIC(10,4) | Return on ad spend: net_revenue / spend (max 9.84) |

**Group 6: Calculated Columns Added in SQL (6 columns)**

| Column | Formula | Business Purpose |
|---|---|---|
| breakeven_roas | selling_price / (selling_price - product_cost) | Minimum ROAS to cover cost of goods, the illusion benchmark |
| contribution_margin | net_revenue - (product_cost x purchases) | What remains after paying for goods sold |
| net_profit | contribution_margin - fixed_cost_allocation | True bottom line after all costs |
| fatigue_status | Based on fatigue_score buckets | Low (0-4), Medium (4-7), High (7-10) |
| performance_category | ROAS vs breakeven_roas | Extreme Winner, Genuine Winner, Break-Even, Illusion, Obvious Loser |
| funnel_dropoff_rate | purchases / impressions | Percentage of impressions that became a purchase |

---

## Data Cleaning Process

Cleaning followed a deliberate, ordered sequence in PostgreSQL, with each step designed to catch a specific class of data quality issue before it could carry through into the normalized tables.

**Step 1: Load Raw**
All 38 columns were loaded into a staging table (fitpulse_raw) exactly as they came from the CSV. row_id was typed as VARCHAR (not INTEGER) to accommodate the _dup suffix on duplicate rows.

**Step 2: Explore**
Ran an initial SELECT * inspection to check the date range, categorical values, and numeric ranges before touching anything.

**Step 3: Duplicate Check**
Identified and counted rows tagged _dup (approximately 1% of all rows) before removing them.

\```sql
SELECT COUNT(*) AS duplicate_rows
FROM fitpulse_raw
WHERE row_id LIKE '%_dup';

DELETE FROM fitpulse_raw
WHERE row_id LIKE '%_dup';
\```

<img width="1510" height="577" alt="fitpilse chckduplicate" src="https://github.com/user-attachments/assets/c73b275a-3f87-44da-8709-0b86f19d789f" />

**Figure 4: Screenshot of the duplicate-removal query and before/after row counts.**

**Step 4: NULL Audit Across All 38 Columns**
Ran one unified query checking all 38 columns for NULLs at the same time, rather than checking column by column. Confirmed NULLs were isolated to hook_rate and completion_rate only. Confirmed zero NULLs in product_cost and fixed_cost_allocation, which are critical for downstream profitability calculations.

\```sql
SELECT
  COUNT(*) FILTER (WHERE hook_rate IS NULL) AS null_hook_rate,
  COUNT(*) FILTER (WHERE completion_rate IS NULL) AS null_completion_rate,
  COUNT(*) FILTER (WHERE product_cost IS NULL) AS null_product_cost,
  COUNT(*) FILTER (WHERE fixed_cost_allocation IS NULL) AS null_fixed_cost
  -- ... all 38 columns checked in one query
FROM fitpulse_raw;
\```


<img width="1542" height="1022" alt="fitpulde null audit" src="https://github.com/user-attachments/assets/7c54a70c-aea0-4720-a049-30c1f0c3b138" />

*Figure 5: Screenshot of the SQL NULL-audit query and result sample set in pgAdmin.*

**Step 5: Categorical Cleanup**
Standardized inconsistent casing (meta, TIKTOK, youtube became Meta, TikTok, YouTube) and stripped campaign name noise (_v2, _test, _copy suffixes) using REGEXP_REPLACE.

**Step 6: NULL Imputation**
hook_rate and completion_rate NULLs were imputed with column averages. CPA NULLs were deliberately left as NULL rather than imputed, because a zero-purchase row cannot mathematically produce a cost-per-acquisition. This was a judgment call to preserve data integrity rather than mask it.

**Step 7: Numeric Validation**
Confirmed engagement rate columns all fell within 0 to 1, ROAS stayed below 10, no negative spend or revenue values existed, and frequency never fell below 1.0.

**Step 8: Calculated Columns**
Six new columns were added using ALTER TABLE, then populated using UPDATE, with NULLIF throughout to prevent division-by-zero errors.

\```sql
ALTER TABLE fitpulse_raw ADD COLUMN breakeven_roas NUMERIC(10,4);

UPDATE fitpulse_raw
SET breakeven_roas = ROUND(
  selling_price / NULLIF(selling_price - product_cost, 0), 4);
\```

<img width="1530" height="1002" alt="fitpulse calculated column" src="https://github.com/user-attachments/assets/e84346f0-b2a3-4951-8290-bafe66682f64" />

*Figure 6: Screenshot of the calculated-columns ALTER TABLE/UPDATE sequence.*

**Step 9: Backup**
A full clean flat table backup was created before normalization began.

\```sql
CREATE TABLE fitpulse_clean_backup AS
SELECT * FROM fitpulse_raw;
\```

Lesson learned the hard way: Use ALTER TABLE to change a column data type, never DROP TABLE and recreate. Dropping the table loses all loaded data and requires a full CSV reimport.

---

## Database Normalization and Views

After cleaning, the flat table was split into 5 relational tables connected via surrogate keys. Zero orphaned foreign key relationships were confirmed after all inserts.

- **dim_date** (PK: date): date lookup: day, week, month, quarter, year
- **products** (PK: product): 8 rows, one per product, product economics
- **ad_creative** (PK: row_id): parent table, FK to products and dim_date
- **ad_performance** (PK: performance_id): child table, FK to row_id, sequence P000001
- **revenue** (PK: revenue_id): child table, FK to row_id, sequence R000001

dim_date was populated using PostgreSQL's generate_series function to create one row for every date from 2023-01-01 to 2024-12-31 (731 rows total). ad_performance and revenue used custom sequences (perf_seq and rev_seq) to auto-generate formatted primary keys in the pattern P000001 and R000001.

A single master view, vw_performance_master, joins all 5 tables and exposes every column needed for the Performance dashboard. Power BI connects to this one view rather than querying individual tables, keeping the data model simple and the source of truth centralized.

<img width="1521" height="1017" alt="fitpulse master view" src="https://github.com/user-attachments/assets/279e7900-5955-4037-b39a-be9401ef96a5" />

*Figure 7: Screenshot of the vw_performance_master view definition in pgAdmin.*

<img width="1885" height="1007" alt="fitpulse model view" src="https://github.com/user-attachments/assets/ed1d2fe4-aac9-448c-a1a8-ffb6cc741902" />

*Figure 8: Screenshot of the Power BI model view showing the relationship between vw_performance_master and dim_date.*

---

## KPIs and Why They Were Chosen

| KPI | Why It Was Chosen |
|---|---|
| Total Spend | Establishes the scale of the investment. A ROAS of 3 means very different things at $1,000 spend versus $1M spend. |
| Blended ROAS | The headline metric leadership actually sees. Deliberately called blended because it averages across everything and can look healthy while individual product ROAS sits below breakeven. This is where the illusion lives. |
| Total Purchases | Anchors the dashboard to real business outcomes, not vanity metrics like impressions or clicks. |
| Avg Fatigue Score | A leading indicator. Rising fatigue predicts future ROAS decline before it shows up in the headline number. |
| Cost per Unique Reach | Separates genuine audience growth from repeated exposure to the same people. |
| Hook Rate / Hold Rate / Completion Rate | Diagnoses exactly where attention is lost in the creative funnel, not just whether an ad worked. |
| CTR vs CVR (paired) | Distinguishes traffic-quality platforms from conversion-quality platforms. A platform can win on one and lose badly on the other. |
| ROAS vs Breakeven ROAS | The core diagnostic of the whole project. ROAS alone cannot tell you if a campaign is profitable. |

<img width="1918" height="1017" alt="kpi dax measures" src="https://github.com/user-attachments/assets/252d97a9-f11c-48e5-bd26-e22f069065a0" />

*Figure 9: Screenshot of the KPI DAX measures pane in Power BI.*

---

## Dashboard Pages

### Page 1: Executive Summary
**Question:** What is the overall performance headline for FitPulse: are we spending to grow, or spending to survive?

**Findings:** $18.53M spend generated $62.36M gross and $53.65M net revenue, but Blended ROAS of 3.2 sits below the 4.41 breakeven threshold. ROAS has declined for 8 consecutive quarters. 37.38% of campaigns are confirmed Obvious Losers; only 5.98% are Extreme Winners.

**Key Insight:** Revenue growth is actively masking a profitability crisis. The headline numbers look healthy while the underlying unit economics are not.

<img width="1612" height="687" alt="fitpulse overview" src="https://github.com/user-attachments/assets/560f6fd0-62b6-4575-adac-daf7c8c99373" />

*Figure 10: Executive Summary dashboard page.*

### Page 2: Awareness
**Question:** Are we reaching the right people, and is our money in the right place?

**Findings:** Frequency is nearly identical across all 4 platforms (3.46 to 3.48), no platform is structurally better at avoiding audience overexposure. Cost efficiency diverges sharply though: TikTok is the cheapest platform to reach people on ($0.03 per reach, CPM 8.6), while YouTube is the most expensive ($0.05 per reach, CPM 15.9), nearly double, for equivalent reach and frequency.

**Key Insight:** Reach efficiency and audience overexposure are two separate problems. FitPulse's overexposure are two separate problems. FitPulse's overexposure issue is universal across platforms, but its cost-efficiency gap is entirely platform-driven, with YouTube the clear underperformer.

<img width="1618" height="706" alt="fitpulse 2" src="https://github.com/user-attachments/assets/a79f88fe-3c2f-4457-8cae-886492be4a07" />

*Figure 11: Awareness dashboard page .*

### Page 3: Attention
**Question:** When people see the ad, are they stopping, watching, and staying?

**Findings:** Hook rate averages 15.3%, but falls to 6.3% hold rate and 2.3% completion rate, roughly 85% of engaged viewers disengage before completion. UGC shows no meaningful advantage over non-UGC creative in any platform or format. A year-over-year comparison revealed hook rate nearly halved between 2023 and 2024 (e.g., TikTok 20.2% to 11.0%), while the proportional shape of the drop-off funnel stayed stable, meaning creatives got worse at earning attention, not worse at holding it once earned.

**Key Insight:** The attention collapse is a volume problem, not a retention problem, and it tracks closely with the fatigue trend found on the Efficiency page.

<img width="1621" height="693" alt="fitpulse 3" src="https://github.com/user-attachments/assets/c05e1b08-a569-4675-afad-90dd87cd3f7a" />

*Figure 12: Attention dashboard page .*

### Page 4: Interest and Conversion
**Question:** Are clicks turning into purchases, and where is the funnel leaking?

**Findings:** TikTok delivers the highest CTR and cheapest clicks on every single product, but converts at roughly a third the rate of Google across the board (e.g., Creatine: TikTok 2.20% CVR vs. Google 6.40% CVR). Google is the inverse: pricier, fewer clicks, but consistently 3x the purchase rate. Resistance Bands has the highest customer acquisition cost ($32.1); Dumbbells and Yoga Mat are cheapest ($21.8 to $22.8).

**Key Insight:** The funnel does not leak evenly. It leaks specifically and consistently on TikTok, post-click, reflecting a platform-level mismatch between scroll-driven curiosity traffic and purchase-ready search traffic.

<img width="1606" height="708" alt="fitpulse 4" src="https://github.com/user-attachments/assets/942ba1e8-5796-4ed9-b654-5da37f996d6a" />

*Figure 13: Interest and Conversion dashboard page .*

### Page 5: Efficiency
**Question:** Was the spend worth it, and can we do more of it?

**Findings:** At the aggregate level, every single product and platform combination is flagged Kill on the Campaign Scalability Matrix. Filtering by fatigue status resolves this: at Low Fatigue, blended ROAS clears breakeven (4.5 vs. 4.42) and every combination flips to Optimise. At Medium and High Fatigue, ROAS collapses to 2.6 and 1.3 respectively. A year-over-year comparison showed average fatigue score doubling (3.0 to 6.0) between 2023 and 2024, alongside blended ROAS falling from 4.4 (near breakeven) to 2.1, and the Kill-flagged share of campaigns rising from 13.4% to 82.6%.

**Key Insight:** FitPulse's decline is not a chronic, unsolvable problem. It is a fatigue-driven, dateable collapse. Campaigns are healthy while fresh and fail predictably once fatigue crosses a threshold, meaning the fix is a creative-refresh cadence tied to fatigue score, not a wholesale platform or product exit.

<img width="1608" height="707" alt="fitpulse 5" src="https://github.com/user-attachments/assets/34f0c964-5886-42b3-a77d-dba01ce69e63" />

*Figure 14: Efficiency dashboard page .*

### Page 6: Decision Center
**Question:** Where should FitPulse protect, cut, or invest?

**Findings:** $10.2M in active spend sits in campaigns that will never break even. Protein Bars is the worst performer in every single cut of the data (platform, year, and aggregate), its breakeven gap is negative everywhere, from -1.7 on Google to -4.3 on YouTube. Whey Protein is the strongest counter-example, the only product still ROAS-positive on Google (+2.1). Quarterly ROAS trends show a steady, continuous decline across all 8 quarters on every platform, not a sudden 2024 event, but a gradual erosion that crossed the breakeven line partway through 2024.

**Key Insight:** The recommended action is precise, not blanket: cut Protein Bars everywhere, concentrate remaining spend on Whey Protein and Creatine specifically on Google and TikTok, and tie creative refresh timing to fatigue score rather than waiting for ROAS to visibly collapse.

<img width="1618" height="708" alt="fitpulse 6" src="https://github.com/user-attachments/assets/075a3696-5061-4144-9984-132487142026" />

*Figure 15: Decision Center dashboard page .*

---

## Overall Key Findings

- FitPulse's core problem is the breakeven illusion: ROAS looks acceptable in aggregate while individual products and platforms sit below the return needed to actually cover cost of goods
- The performance decline is fatigue-driven and gradual, not sudden. Average fatigue score doubled over 2 years, and ROAS eroded in lockstep, quarter over quarter, on every platform
- TikTok and Google play opposite roles in the funnel: TikTok brings cheap, high-volume, low-intent traffic; Google brings pricier, lower-volume, high-intent traffic that converts 2.5 to 3x better
- Protein Bars is a universal underperformer, the only product that fails to clear breakeven on every platform and in every year examined
- A meaningful share of campaigns are genuinely healthy. The "everything is Kill" read is only true in aggregate. Segmenting by fatigue status reveals a real, currently underfunded tier of scalable campaigns

---

## Recommendations

1. Cut Protein Bars campaigns across all platforms and recover the associated spend
2. Concentrate reallocated budget on Whey Protein and Creatine, prioritizing Google and TikTok
3. Move to a fatigue-triggered creative refresh cadence rather than a fixed schedule. Refresh before fatigue score crosses from Low into Medium, where the ROAS cliff is steepest
4. Rebalance platform budget by funnel stage, not just blended ROAS. Use TikTok for top-of-funnel reach efficiency, but route bottom-funnel conversion budget toward Google
5. Investigate the TikTok conversion gap specifically. Audit landing pages, offer relevance, and purchase-intent signals rather than assuming the traffic itself is low quality

---

## Caveats and Limitations

- This dataset is fully synthetic, generated via Python with an intentionally designed breakeven and fatigue narrative. It is a modeling and analysis exercise, not real FitPulse operating data
- The Campaign Scalability Matrix is sensitive to the Fatigue Status filter. Read without that segmentation, it overstates the severity of the Kill verdict
- The dashboard does not include a dedicated attention trap visual (high hook rate paired with low completion rate for the same creative). This analysis requires manually cross-referencing two separate visuals
- Findings are Performance-only. Profitability metrics (contribution margin, net profit, true breakeven at the P&L level) are covered in the companion Profitability analysis

---

## How to Explore

The full interactive Power BI dashboard is available here: [View Dashboard](https://app.powerbi.com/links/kKXhrcmsky?ctid=f6f117ef-72a8-4267-9390-7c30e90fd172&pbi_source=linkShare)

Filter by Year, Month, Platform, Product, Ad Format, or Fatigue Status on any page to reproduce the findings above or explore further.

---

## Author and Contact

**Olivia Anetoh**
Data Analyst, Marketing and Business Analytics

LinkedIn: [linkedin.com/in/olivia-anetoh-955b94328](https://www.linkedin.com/in/olivia-anetoh-955b94328)
GitHub: [github.com/Olivia-Micheal](https://github.com/Olivia-Micheal)
Email: anetohchinecherem@gmail.com
