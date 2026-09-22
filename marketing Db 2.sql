SELECT*
FROM fitpulse_raw;

----CREATE INDEXEX FOR QUERY OPTIMIZATION
 -- On ad_creative 
CREATE INDEX idx_ac_platform ON ad_creative(platform);
CREATE INDEX idx_ac_product  ON ad_creative(product);
CREATE INDEX idx_ac_date     ON ad_creative(date);

-- Index on foreign key columns 
CREATE INDEX idx_ap_row_id   ON ad_performance(row_id);
CREATE INDEX idx_rv_row_id   ON revenue(row_id);

-- On commonly filtered columns
CREATE INDEX idx_ap_fatigue  ON ad_performance(fatigue_status);
CREATE INDEX idx_rv_perf_cat ON revenue(performance_category);

----- List all indexes on your tables
SELECT
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN (
    'ad_creative','ad_performance','revenue','dim_date','products'
)
ORDER BY tablename, indexname;


---EXPLAIN ANALYZE
SELECT ac.platform, ROUND(AVG(rv.ROAS), 2) AS avg_roas
FROM ad_creative ac
JOIN ad_performance ap ON ac.row_id = ap.row_id
JOIN revenue rv ON ac.row_id = rv.row_id
GROUP BY ac.platform;




---------MARKETING PERFORMANCE QUESTIONS
-- Which platform is generating the most reach and is it the same audience seeing the ad repeatedly or new people?
SELECT
    ac.platform,
    COUNT(*)AS total_campaigns,
    SUM(ap.impressions)AS total_impressions,
    SUM(ap.reach)AS total_reach,
    ROUND(AVG(ap.frequency), 2)AS avg_frequency,
    ROUND(AVG(ap.fatigue_score), 2)AS avg_fatigue_score,
    ROUND(SUM(ap.spend), 2)AS total_spend,
    ROUND(SUM(ap.spend) /
          NULLIF(SUM(ap.reach), 0), 4)AS cost_per_unique_reach
FROM ad_creative ac
JOIN ad_performance ap 
ON ac.row_id = ap.row_id
GROUP BY ac.platform
ORDER BY total_impressions DESC;


--- Is our spend going to the platforms and products that actually deserve it based on results?
WITH spend_summary AS (
    SELECT
        ac.platform,
        ac.product,
        ROUND(SUM(ap.spend), 2)AS total_spend,
        ROUND(AVG(rv.ROAS), 2)AS avg_roas,
        ROUND(AVG(rv.breakeven_roas), 2)AS avg_breakeven
    FROM ad_creative ac
    JOIN ad_performance ap ON ac.row_id = ap.row_id
    JOIN revenue        rv ON ac.row_id = rv.row_id
    GROUP BY ac.platform, ac.product
),
grand_total AS (
    SELECT SUM(total_spend) AS total_spend FROM spend_summary
)
SELECT
    ss.platform,
    ss.product,
    ss.total_spend,
    ROUND(ss.total_spend / gt.total_spend * 100, 2)   AS spend_share_pct,
    ss.avg_roas,
    ss.avg_breakeven,
    ROUND(ss.avg_roas - ss.avg_breakeven, 2)     AS roas_vs_breakeven_gap,
    CASE
        WHEN ss.avg_roas >= ss.avg_breakeven
        THEN 'Spend Justified'
        ELSE 'Spend Not Justified'
    END AS spend_verdict
FROM spend_summary ss
CROSS JOIN grand_total gt
ORDER BY ss.total_spend DESC;


--Which creative combination stops the scroll hook type, angle, format, UGC?
SELECT
    ac.hook_type,
    ac.creative_angle,
    ac.copy_tone,
    ac.has_ugc,
    COUNT(*) AS total_ads,
    ROUND(AVG(ap.hook_rate), 4) AS avg_hook_rate,
    ROUND(AVG(ap.hold_rate_3s), 4) AS avg_hold_rate,
    ROUND(AVG(ap.completion_rate), 4)AS avg_completion_rate,
    ROUND(AVG(rv.ROAS), 2)AS avg_roas
FROM ad_creative ac
JOIN ad_performance ap
ON ac.row_id = ap.row_id
JOIN revenue rv
ON ac.row_id = rv.row_id
GROUP BY ac.hook_type, ac.creative_angle, ac.copy_tone, ac.has_ugc
HAVING COUNT(*) >= 10
ORDER BY avg_hook_rate DESC
LIMIT 20;


----After stopping are they staying — hook to hold to completion?
---where are we losing people
SELECT
    ac.platform,
    ac.ad_format,
    COUNT(*) AS total_ads,
    ROUND(AVG(ap.hook_rate), 4)AS avg_hook_rate,
    ROUND(AVG(ap.hold_rate_3s), 4)AS avg_hold_rate,
    ROUND(AVG(ap.completion_rate), 4)AS avg_completion_rate,
    ROUND(AVG(ap.hold_rate_3s) /
          NULLIF(AVG(ap.hook_rate), 0), 4)AS hook_to_hold_ratio,
    ROUND(AVG(ap.completion_rate) /
          NULLIF(AVG(ap.hold_rate_3s), 0), 4)AS hold_to_completion_ratio
FROM ad_creative ac
JOIN ad_performance ap 
ON ac.row_id = ap.row_id
GROUP BY ac.platform, ac.ad_format
ORDER BY avg_completion_rate DESC;


--- Where exactly are we losing people in the attention funnel?
CREATE TEMP TABLE temp_attention_traps AS
SELECT
    ac.ad_id,
    ac.platform,
    ac.product,
    ac.hook_type,
    ac.ad_format,
    ROUND(AVG(ap.hook_rate), 4) AS avg_hook_rate,
    ROUND(AVG(ap.completion_rate), 4) AS avg_completion_rate,
    ROUND(AVG(ap.CVR), 4) AS avg_cvr,
    ROUND(AVG(rv.ROAS), 2)AS avg_roas,
    ROUND(SUM(ap.spend), 2)AS total_spend
FROM ad_creative ac
JOIN ad_performance ap 
ON ac.row_id = ap.row_id
JOIN revenue rv 
ON ac.row_id = rv.row_id
GROUP BY ac.ad_id, ac.platform, ac.product,
         ac.hook_type, ac.ad_format
HAVING AVG(ap.hook_rate) > 0.18
AND AVG(ap.completion_rate) < 0.05;

-- Query the attention traps with retention ratio
SELECT *,
    ROUND(avg_completion_rate /
          NULLIF(avg_hook_rate, 0), 4)AS retention_ratio
FROM temp_attention_traps
ORDER BY avg_hook_rate DESC;

--  how much spend is going to attention trap creatives
SELECT
    COUNT(*)AS trap_count,
    ROUND(SUM(total_spend), 2)AS spend_on_traps
FROM temp_attention_traps;


---INTEREST
---Which platform sends quality clicks — not just volume? 
SELECT
    ac.platform,
    COUNT(*) AS total_campaigns,
    SUM(ap.clicks) AS total_clicks,
    SUM(ap.impressions) AS total_impressions,
    ROUND(AVG(ap.CTR), 4) AS avg_ctr,
    ROUND(AVG(ap.CPC), 2) AS avg_cpc,
    ROUND(SUM(ap.spend), 2) AS total_spend,
    ROUND(SUM(ap.clicks)::NUMERIC /
          NULLIF(SUM(ap.impressions), 0), 4) AS blended_ctr
FROM ad_creative ac
JOIN ad_performance ap
ON ac.row_id = ap.row_id
GROUP BY ac.platform
ORDER BY blended_ctr DESC;

--- Is the creative attracting the right audience or just curious people who will not buy?
SELECT
    ac.hook_type,
    ac.creative_angle,
    ac.ad_format,
    ac.has_ugc,
    COUNT(*) AS total_ads,
    ROUND(AVG(ap.CTR), 4) AS avg_ctr,
    ROUND(AVG(ap.CPC), 2) AS avg_cpc,
    ROUND(AVG(ap.CVR), 4)AS avg_cvr,
    ROUND(AVG(rv.ROAS), 2) AS avg_roas
FROM ad_creative ac
JOIN ad_performance ap ON ac.row_id = ap.row_id
JOIN revenue rv ON
ac.row_id = rv.row_id
GROUP BY ac.hook_type, ac.creative_angle, ac.ad_format, ac.has_ugc
HAVING COUNT(*) >= 10
ORDER BY avg_ctr DESC
LIMIT 20;

---CONVERSION
--- Where is the funnel leaking — before the click or after?
SELECT
    ac.platform,
    ac.product,
    SUM(ap.impressions) AS total_impressions,
    SUM(ap.clicks) AS total_clicks,
    SUM(ap.purchases) AS total_purchases,
    ROUND(SUM(ap.clicks)::NUMERIC /
          NULLIF(SUM(ap.impressions), 0) * 100, 2)  AS impression_to_click_pct,
    ROUND(SUM(ap.purchases)::NUMERIC /
          NULLIF(SUM(ap.clicks), 0) * 100, 2)       AS click_to_purchase_pct,
    ROUND(SUM(ap.purchases)::NUMERIC /
          NULLIF(SUM(ap.impressions), 0) * 100, 4)  AS overall_funnel_pct,
    CASE
        WHEN ROUND(SUM(ap.clicks)::NUMERIC /
             NULLIF(SUM(ap.impressions), 0)*100, 2) < 2
        THEN 'Traffic Problem — low CTR before click'
        WHEN ROUND(SUM(ap.purchases)::NUMERIC /
             NULLIF(SUM(ap.clicks), 0)*100, 2) < 3
        THEN 'Conversion Problem — low CVR after click'
        ELSE 'Funnel Healthy'
    END AS funnel_diagnosis
FROM ad_creative ac
JOIN ad_performance ap
ON ac.row_id = ap.row_id
GROUP BY ac.platform, ac.product
ORDER BY overall_funnel_pct ASC;


---- Which creatives get clicks but fail to convert?
WITH creative_metrics AS (
    SELECT
        ac.ad_id,
        ac.platform,
        ac.product,
        ac.hook_type,
        ac.creative_angle,
        ac.copy_tone,
        ROUND(AVG(ap.CTR), 4)            AS avg_ctr,
        ROUND(AVG(ap.CVR), 4)            AS avg_cvr,
        ROUND(AVG(rv.ROAS), 2)           AS avg_roas,
        ROUND(AVG(rv.breakeven_roas),2)  AS avg_breakeven,
        ROUND(SUM(ap.spend), 2)          AS total_spend,
        COUNT(*)                          AS campaign_count
    FROM ad_creative ac
    JOIN ad_performance ap ON ac.row_id = ap.row_id
    JOIN revenue        rv ON ac.row_id = rv.row_id
    GROUP BY ac.ad_id, ac.platform, ac.product,
             ac.hook_type, ac.creative_angle, ac.copy_tone
    HAVING COUNT(*) >= 5
)
SELECT *,
    CASE
        WHEN avg_ctr > 0.03 AND avg_cvr < 0.02
        THEN 'Click Trap attracting wrong audience'
        ELSE 'Review'
    END AS creative_diagnosis
FROM creative_metrics
WHERE avg_ctr > 0.03 AND avg_cvr < 0.02
ORDER BY total_spend DESC;

-- Total spend wasted on click trap creatives
WITH creative_metrics AS (
    SELECT
        ac.ad_id,
        ac.platform,
        ac.product,
        ac.hook_type,
        ac.creative_angle,
        ac.copy_tone,
        ROUND(AVG(ap.CTR), 4)           AS avg_ctr,
        ROUND(AVG(ap.CVR), 4)           AS avg_cvr,
        ROUND(AVG(rv.ROAS), 2)          AS avg_roas,
        ROUND(AVG(rv.breakeven_roas),2) AS avg_breakeven,
        ROUND(SUM(ap.spend), 2)         AS total_spend,
        COUNT(*)                         AS campaign_count
    FROM ad_creative ac
    JOIN ad_performance ap ON ac.row_id = ap.row_id
    JOIN revenue       rv  ON ac.row_id = rv.row_id
    GROUP BY ac.ad_id, ac.platform, ac.product,
             ac.hook_type, ac.creative_angle, ac.copy_tone
    HAVING COUNT(*) >= 5
)
SELECT
    COUNT(*)                   AS click_trap_count,
    ROUND(SUM(total_spend), 2) AS total_wasted_spend
FROM creative_metrics
WHERE avg_ctr > 0.03 AND avg_cvr < 0.02;



---EFFICIENCY
-- Which ads are fatiguing and when does performance collapse?
WITH fatigue_bands AS (
    SELECT
        ac.platform,
		 ac.product,
        ac.ad_id,
        CASE
            WHEN ap.fatigue_score < 2  THEN '1. Low (0-2)'
            WHEN ap.fatigue_score < 4  THEN '2. Low-Mid (2-4)'
            WHEN ap.fatigue_score < 6  THEN '3. Mid (4-6)'
            WHEN ap.fatigue_score < 8  THEN '4. High (6-8)'
            ELSE                            '5. Critical (8-10)'
        END AS fatigue_band,
        ROUND(AVG(ap.frequency), 2) AS avg_frequency,
        ROUND(AVG(ap.hook_rate), 4) AS avg_hook_rate,
        ROUND(AVG(ap.CTR), 4) AS avg_ctr,
        ROUND(AVG(ap.CVR), 4) AS avg_cvr,
        ROUND(AVG(rv.ROAS), 2) AS avg_roas,
        COUNT(*) AS total_campaigns
    FROM ad_creative ac
    JOIN ad_performance ap 
	ON ac.row_id = ap.row_id
    JOIN revenue rv
	ON ac.row_id = rv.row_id
    GROUP BY ac.platform, ac.product, ac.ad_id, fatigue_band
)
SELECT *,
    ROUND(avg_roas - LAG(avg_roas) OVER (
        PARTITION BY platform
        ORDER BY fatigue_band
    ), 2) AS roas_change_vs_prev_band
FROM fatigue_bands
ORDER BY platform, fatigue_band;


--- Which ads are worth scaling and which should be killed?
SELECT
    ac.platform,
    ac.product,
    ac.ad_id,
    ac.hook_type,
    ROUND(AVG(ap.fatigue_score), 1)AS avg_fatigue,
    ap.fatigue_status,
    ROUND(AVG(rv.ROAS), 2) AS avg_roas,
    ROUND(AVG(rv.breakeven_roas), 2) AS avg_breakeven,
    ROUND(AVG(rv.ROAS) -
          AVG(rv.breakeven_roas), 2) AS roas_vs_breakeven_gap,
    ROUND(SUM(ap.spend), 2)AS total_spend,
    CASE
        WHEN AVG(rv.ROAS) >= AVG(rv.breakeven_roas)
             AND ap.fatigue_status = 'Low Fatigue'
             THEN 'Scale'
        WHEN AVG(rv.ROAS) >= AVG(rv.breakeven_roas)
             AND ap.fatigue_status = 'Medium Fatigue'
             THEN 'Monitor'
        WHEN AVG(rv.ROAS) < AVG(rv.breakeven_roas)
             AND ap.fatigue_status = 'Low Fatigue'
             THEN 'Optimise'
        ELSE 'Kill'
    END AS scalability_decision
FROM ad_creative ac
JOIN ad_performance ap
ON ac.row_id = ap.row_id
JOIN revenue rv
ON ac.row_id = rv.row_id
GROUP BY ac.platform, ac.product, ac.ad_id,
         ac.hook_type, ap.fatigue_status
ORDER BY
    CASE
        WHEN AVG(rv.ROAS) >= AVG(rv.breakeven_roas)
             AND ap.fatigue_status = 'Low Fatigue'    THEN 1
        WHEN AVG(rv.ROAS) >= AVG(rv.breakeven_roas)
             AND ap.fatigue_status = 'Medium Fatigue' THEN 2
        WHEN AVG(rv.ROAS) < AVG(rv.breakeven_roas)
             AND ap.fatigue_status = 'Low Fatigue'    THEN 3
        ELSE 4
    END,
    total_spend DESC;


----- 	How does performance shift across seasons?


WITH quarterly AS (
    SELECT
        ac.product,
        ac.platform,
        d.year_quarter,
        d.year,
        d.quarter,
        ROUND(AVG(rv.ROAS), 2)              AS avg_roas,
        ROUND(AVG(rv.breakeven_roas), 2)    AS avg_breakeven,
        ROUND(SUM(ap.spend), 2)             AS total_spend,
        COUNT(*)                             AS campaigns
    FROM ad_creative ac
    JOIN dim_date       d  ON ac.date   = d.date
    JOIN ad_performance ap ON ac.row_id = ap.row_id
    JOIN revenue        rv ON ac.row_id = rv.row_id
    GROUP BY ac.product, ac.platform,
             d.year_quarter, d.year, d.quarter
)
SELECT *,
    ROUND(avg_roas - LAG(avg_roas) OVER (
        PARTITION BY product, platform
        ORDER BY year, quarter
    ), 2) AS roas_change_vs_prev_quarter,
    CASE
        WHEN avg_roas >= avg_breakeven THEN 'Profitable'
        ELSE 'Below Breakeven'
    END AS quarter_status
FROM quarterly
ORDER BY product, platform, year, quarter;




-----------PROFITABILITY--------
---- Which platform and product generates the most gross revenue?
SELECT
    ac.platform,
    ac.product,
    COUNT(*) AS total_campaigns,
    SUM(ap.purchases) AS total_purchases,
    ROUND(SUM(rv.gross_revenue), 2) AS total_gross_revenue,
    ROUND(SUM(ap.spend), 2)AS total_spend,
    ROUND(SUM(rv.gross_revenue) /
          NULLIF(SUM(ap.spend), 0), 2) AS gross_roas,
    ROUND(AVG(rv.gross_revenue), 2)AS avg_gross_per_campaign
FROM ad_creative ac
JOIN ad_performance ap
ON ac.row_id = ap.row_id
JOIN revenue rv
ON ac.row_id = rv.row_id
GROUP BY ac.platform, ac.product
ORDER BY total_gross_revenue DESC;


--- How does gross revenue trend across quarters — is it growing or declining?
SELECT
    d.year_quarter,
    d.year,
    d.quarter,
    ROUND(SUM(rv.gross_revenue), 2)AS total_gross_revenue,
    ROUND(SUM(rv.net_revenue), 2)AS total_net_revenue,
    ROUND(SUM(ap.spend), 2) AS total_spend,
    ROUND(AVG(rv.ROAS), 2)AS avg_roas,
    ROUND(SUM(rv.gross_revenue) -
          SUM(rv.net_revenue), 2) AS total_deductions
FROM ad_creative ac
JOIN dim_date d  
ON ac.date = d.date
JOIN ad_performance ap
ON ac.row_id = ap.row_id
JOIN revenue rv 
ON ac.row_id = rv.row_id
GROUP BY d.year_quarter, d.year, d.quarter
ORDER BY d.year, d.quarter;


---- REVENUE KEPT
---Which product loses the most revenue to discounts and refunds?
SELECT
    ac.product,
    ac.platform,
    ROUND(SUM(rv.gross_revenue), 2)AS total_gross,
    ROUND(SUM(rv.discount_amount), 2) AS total_discounts,
    ROUND(SUM(rv.refund_amount), 2)AS total_refunds,
    ROUND(SUM(rv.net_revenue), 2) AS total_net_revenue,
    ROUND(SUM(rv.discount_amount) /
          NULLIF(SUM(rv.gross_revenue),0)*100,2) AS discount_leakage_pct,
    ROUND(SUM(rv.refund_amount) /
          NULLIF(SUM(rv.gross_revenue),0)*100,2) AS refund_leakage_pct,
    ROUND(SUM(rv.net_revenue) /
          NULLIF(SUM(rv.gross_revenue),0)*100,2) AS revenue_retention_pct
FROM ad_creative ac
JOIN revenue rv 
ON ac.row_id = rv.row_id
GROUP BY ac.product, ac.platform
ORDER BY revenue_retention_pct ASC;


--- Does Q4 discounting hurt net revenue even when gross looks strong?
SELECT
    d.year_quarter,
    d.quarter,
    ROUND(SUM(rv.gross_revenue), 2)              AS total_gross,
    ROUND(SUM(rv.discount_amount), 2)            AS total_discounts,
    ROUND(SUM(rv.refund_amount), 2)              AS total_refunds,
    ROUND(SUM(rv.net_revenue), 2)                AS total_net,
    ROUND(SUM(rv.net_revenue) /
          NULLIF(SUM(rv.gross_revenue),0)*100,2) AS revenue_retention_pct
FROM ad_creative ac
JOIN dim_date  d  ON ac.date   = d.date
JOIN revenue   rv ON ac.row_id = rv.row_id
GROUP BY d.year_quarter, d.quarter
ORDER BY d.year_quarter;


--- Which product has the healthiest contribution margin after product cost?
SELECT
    ac.product,
    ROUND(SUM(rv.net_revenue), 2)AS total_net_revenue,
    ROUND(SUM(rv.contribution_margin), 2)AS total_contribution_margin,
    ROUND(SUM(rv.contribution_margin) /
          NULLIF(SUM(rv.net_revenue), 0) * 100, 2)AS margin_retention_pct,
    CASE
        WHEN SUM(rv.contribution_margin) /
             NULLIF(SUM(rv.net_revenue), 0) < 0.15
        THEN 'Danger — Thin Margin'
        WHEN SUM(rv.contribution_margin) /
             NULLIF(SUM(rv.net_revenue), 0) < 0.30
        THEN 'Moderate — Monitor'
        ELSE 'Healthy Margin'
    END AS margin_health
FROM ad_creative ac
JOIN revenue rv 
ON ac.row_id = rv.row_id
GROUP BY ac.product
ORDER BY total_contribution_margin DESC;


---- Which platform delivers the best contribution margin per spend?
SELECT
    ac.platform,
    ROUND(SUM(rv.contribution_margin), 2)AS total_contribution_margin,
    ROUND(SUM(ap.spend), 2) AS total_spend,
    ROUND(SUM(rv.contribution_margin) /
          NULLIF(SUM(ap.spend), 0), 2)AS contribution_per_spend,
    CASE
        WHEN SUM(rv.contribution_margin) /
             NULLIF(SUM(ap.spend), 0) >= 0.5
        THEN 'Efficient Platform'
        WHEN SUM(rv.contribution_margin) /
             NULLIF(SUM(ap.spend), 0) >= 0.2
        THEN 'Moderate Platform'
        ELSE 'Inefficient Platform'
    END AS platform_efficiency
FROM ad_creative ac
JOIN ad_performance ap 
ON ac.row_id = ap.row_id
JOIN revenue rv  
ON ac.row_id = rv.row_id
GROUP BY ac.platform
ORDER BY contribution_per_spend DESC;


---Are there products with strong revenue but dangerously thin margins?
SELECT
    ac.product,
    ROUND(SUM(rv.gross_revenue), 2) AS total_gross_revenue,
    ROUND(SUM(rv.net_revenue), 2) AS total_net_revenue,
    ROUND(SUM(rv.contribution_margin), 2) AS total_contribution_margin,
    ROUND(SUM(rv.contribution_margin) /
          NULLIF(SUM(rv.net_revenue), 0) * 100, 2)AS margin_pct,
    CASE
        WHEN SUM(rv.contribution_margin) /
             NULLIF(SUM(rv.net_revenue), 0) < 0.15
        THEN 'Margin Illusion — thin margin warning'
        WHEN SUM(rv.contribution_margin) /
             NULLIF(SUM(rv.net_revenue), 0) < 0.30
        THEN 'Moderate Margin — monitor closely'
        ELSE 'Healthy Margin'
    END AS margin_verdict
FROM ad_creative ac
JOIN revenue rv 
ON ac.row_id = rv.row_id
GROUP BY ac.product
ORDER BY total_gross_revenue DESC;


-----TRUE PROFIT
---Which products are genuinely profitable after fixed cost allocation?
SELECT
    ac.product,
    d.year_quarter,
    ROUND(SUM(rv.gross_revenue), 2)              AS total_gross_revenue,
    ROUND(SUM(rv.discount_amount +
              rv.refund_amount), 2)              AS total_deductions,
    ROUND(SUM(rv.net_revenue), 2)                AS total_net_revenue,
    ROUND(SUM(rv.contribution_margin), 2)        AS total_contribution_margin,
    ROUND(SUM(rv.fixed_cost_allocation), 2)      AS total_fixed_costs,
    ROUND(SUM(rv.net_profit), 2)                 AS total_net_profit,
    ROUND(SUM(rv.net_profit) /
          NULLIF(SUM(rv.net_revenue),0)*100,2)   AS net_profit_margin_pct,
    CASE
        WHEN SUM(rv.net_profit) > 0  THEN 'Profitable'
        WHEN SUM(rv.net_profit) = 0  THEN 'Break-Even'
        ELSE 'Loss'
    END AS profit_status
FROM ad_creative ac
JOIN dim_date  d  ON ac.date   = d.date
JOIN revenue   rv ON ac.row_id = rv.row_id
GROUP BY ac.product, d.year_quarter
ORDER BY ac.product, d.year_quarter;


---- Which quarter looks most profitable but is actually most expensive to operate in?
SELECT
    d.year,
    d.quarter,
    CONCAT(d.quarter_label, ' ', d.year)         AS quarter_label_full,
    ROUND(SUM(rv.gross_revenue), 2)              AS total_gross_revenue,
    ROUND(SUM(rv.net_revenue), 2)                AS total_net_revenue,
    ROUND(SUM(ap.spend), 2)                      AS total_ad_spend,
    ROUND(SUM(rv.fixed_cost_allocation), 2)      AS total_fixed_costs,
    ROUND(SUM(rv.contribution_margin), 2)        AS total_contribution_margin,
    ROUND(SUM(rv.net_profit), 2)                 AS total_net_profit,
    ROUND(SUM(rv.net_profit) /
          NULLIF(SUM(ap.spend),0)*100, 2)        AS profit_per_spend_pct
FROM ad_creative ac
JOIN dim_date       d  ON ac.date   = d.date
JOIN ad_performance ap ON ac.row_id = ap.row_id
JOIN revenue        rv ON ac.row_id = rv.row_id
GROUP BY d.year, d.quarter, d.quarter_label
ORDER BY total_net_profit DESC;


-----Where is the breakeven illusion strongest,ROAS looks good but below breakeven?
SELECT
    ac.product,
    ac.platform,
    ROUND(AVG(rv.ROAS), 2) AS avg_roas,
    ROUND(AVG(rv.breakeven_roas), 2)AS avg_breakeven,
    ROUND(AVG(rv.ROAS) -
          AVG(rv.breakeven_roas), 2) AS roas_gap,
    COUNT(*)AS total_campaigns,
    SUM(CASE WHEN rv.ROAS < rv.breakeven_roas
             THEN 1 ELSE 0 END) AS loss_making_campaigns,
    ROUND(SUM(CASE WHEN rv.ROAS < rv.breakeven_roas
                   THEN ap.spend ELSE 0 END),2) AS spend_below_breakeven,
    CASE
        WHEN AVG(rv.ROAS) >= AVG(rv.breakeven_roas)*1.2
             THEN 'Genuinely Profitable'
        WHEN AVG(rv.ROAS) >= AVG(rv.breakeven_roas)
             THEN 'Barely Breaking Even'
        WHEN AVG(rv.ROAS) >= 1.5
             THEN 'Illusion — Losing Money'
        ELSE 'Obvious Loss'
    END AS profitability_verdict
FROM ad_creative ac
JOIN ad_performance ap
ON ac.row_id = ap.row_id
JOIN revenue rv 
ON ac.row_id = rv.row_id
GROUP BY ac.product, ac.platform
ORDER BY roas_gap ASC;


----DECISION
---How much total spend is going to campaigns that will never break even?
WITH category_spend AS (
    SELECT
        rv.performance_category,
        ROUND(SUM(ap.spend), 2)             AS total_spend,
        COUNT(*)                             AS campaigns,
        ROUND(AVG(rv.ROAS), 2)              AS avg_roas,
        ROUND(AVG(rv.breakeven_roas), 2)    AS avg_breakeven
    FROM ad_creative ac
    JOIN ad_performance ap ON ac.row_id = ap.row_id
    JOIN revenue        rv ON ac.row_id = rv.row_id
    GROUP BY rv.performance_category
),
grand AS (SELECT SUM(total_spend) AS total FROM category_spend)
SELECT
    cs.performance_category,
    cs.total_spend,
    ROUND(cs.total_spend / gt.total * 100, 2)  AS spend_share_pct,
    cs.campaigns,
    cs.avg_roas,
    cs.avg_breakeven
FROM category_spend cs
CROSS JOIN grand gt
ORDER BY
    CASE cs.performance_category
        WHEN 'Extreme Winner'  THEN 1
        WHEN 'Genuine Winner'  THEN 2
        WHEN 'Break-Even'      THEN 3
        WHEN 'Illusion'        THEN 4
        ELSE 5
    END;

-- Headline finding for CEO presentation:
SELECT
    ROUND(SUM(CASE WHEN rv.performance_category IN
               ('Illusion','Obvious Loser')
               THEN ap.spend ELSE 0 END), 2)     AS wasted_spend,
    ROUND(SUM(CASE WHEN rv.performance_category IN
               ('Illusion','Obvious Loser')
               THEN ap.spend ELSE 0 END) /
          NULLIF(SUM(ap.spend), 0) * 100, 2)     AS wasted_spend_pct
FROM ad_creative ac
JOIN ad_performance ap ON ac.row_id = ap.row_id
JOIN revenue        rv ON ac.row_id = rv.row_id;


--- Which product and platform combination should be deprioritised?
WITH profit_summary AS (
    SELECT
        ac.product,
        ac.platform,
        ROUND(SUM(ap.spend), 2)                  AS total_spend,
        ROUND(SUM(rv.net_revenue), 2)             AS total_net_revenue,
        ROUND(SUM(rv.contribution_margin), 2)     AS total_contribution_margin,
        ROUND(SUM(rv.net_profit), 2)              AS total_net_profit,
        ROUND(AVG(rv.ROAS), 2)                    AS avg_roas,
        ROUND(AVG(rv.breakeven_roas), 2)          AS avg_breakeven,
        ROUND(AVG(ap.fatigue_score), 1)           AS avg_fatigue
    FROM ad_creative ac
    JOIN ad_performance ap ON ac.row_id = ap.row_id
    JOIN revenue        rv ON ac.row_id = rv.row_id
    GROUP BY ac.product, ac.platform
)
SELECT *,
    CASE
        WHEN total_net_profit > 0
             AND avg_roas >= avg_breakeven * 1.2
             AND avg_fatigue < 5
             THEN 'Double Down'
        WHEN total_net_profit > 0
             AND avg_fatigue >= 5
             THEN 'Maintain'
        WHEN total_net_profit <= 0
             AND avg_roas >= avg_breakeven * 0.9
             THEN 'Optimise'
        ELSE 'Deprioritise'
    END AS ceo_recommendation
FROM profit_summary
ORDER BY
    CASE
        WHEN total_net_profit > 0
             AND avg_roas >= avg_breakeven*1.2
             AND avg_fatigue < 5             THEN 1
        WHEN total_net_profit > 0
             AND avg_fatigue >= 5            THEN 2
        WHEN total_net_profit <= 0
             AND avg_roas >= avg_breakeven*0.9 THEN 3
        ELSE 4
    END,
    total_net_profit DESC;

--- Where should budget be doubled down for profitable growth?	
--
 




















 







































































































































































































