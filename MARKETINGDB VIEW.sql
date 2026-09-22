--CREATING A MASTER VIEW FOR POWER BI
CREATE OR REPLACE VIEW vw_profitability_master AS
SELECT
    -- Identity
    ac.row_id,
    ac.ad_id,
    ac.date,
    d.month_name,
    d.month_number,
    d.quarter,
    d.quarter_label,
    d.year,
    d.year_quarter,
    d.year_month,
    -- Campaign attributes
    ac.platform,
    ac.product,
    -- Product economics
    p.selling_price,
    p.product_cost,
    p.gross_margin_pct,
    -- Spend and purchases
    ap.spend,
    ap.purchases,
    ap.fatigue_score,
    ap.fatigue_status,
    -- Full revenue waterfall
    rv.gross_revenue,
    rv.discount_amount,
    rv.refund_amount,
    rv.net_revenue,
    rv.ROAS,
    rv.breakeven_roas,
    rv.contribution_margin,
    rv.fixed_cost_allocation,
    rv.net_profit,
    rv.performance_category,
    -- Derived profitability metrics
    ROUND(rv.discount_amount /
          NULLIF(rv.gross_revenue,0)*100,2)AS discount_leakage_pct,
    ROUND(rv.refund_amount /
          NULLIF(rv.gross_revenue,0)*100,2)AS refund_leakage_pct,
    ROUND(rv.net_revenue /
          NULLIF(rv.gross_revenue,0)*100,2)AS revenue_retention_pct,
    ROUND(rv.ROAS - rv.breakeven_roas, 2)AS roas_vs_breakeven_gap,
    -- Profit status
    CASE
        WHEN rv.net_profit > 0  THEN 'Profitable'
        WHEN rv.net_profit = 0  THEN 'Break-Even'
        ELSE 'Loss'
    END AS profit_status,
    -- CEO recommendation
    CASE
        WHEN rv.net_profit > 0
             AND rv.ROAS >= rv.breakeven_roas*1.2
             AND ap.fatigue_score < 5
             THEN 'Double Down'
        WHEN rv.net_profit > 0
             AND ap.fatigue_score >= 5
             THEN 'Maintain'
        WHEN rv.net_profit <= 0
             AND rv.ROAS >= rv.breakeven_roas*0.9
             THEN 'Optimise'
        ELSE 'Deprioritise'
    END AS ceo_recommendation
FROM ad_creative ac
JOIN dim_date  d 
ON ac.date = d.date
JOIN products  p  
ON ac.product = p.product
JOIN ad_performance ap 
ON ac.row_id  = ap.row_id
JOIN revenue rv
ON ac.row_id  = rv.row_id;

-- Verify the view
SELECT COUNT(*) AS total_rows FROM vw_profitability_master;
SELECT * FROM vw_profitability_master LIMIT 5;


----
CREATE OR REPLACE VIEW vw_performance_master AS
SELECT
    -- Identity
    ac.row_id,
    ac.campaign_id,
    ac.campaign_name,
    ac.ad_id,
    -- Date dimension
    ac.date,
    d.day_of_week,
    d.week_number,
    d.month_number,
    d.month_name,
    d.quarter,
    d.quarter_label,
    d.year,
    d.year_quarter,
    d.year_month,
    d.is_weekend,
    -- Campaign attributes
    ac.platform,
    ac.product,
    ac.hook_type,
    ac.creative_angle,
    ac.copy_tone,
    ac.ad_format,
    ac.has_ugc,
    -- Product economics
    p.selling_price,
    p.product_cost,
    p.gross_margin_pct,
    -- Funnel and fatigue
    ap.impressions,
    ap.reach,
    ap.frequency,
    ap.fatigue_score,
    ap.fatigue_status,
    ap.creative_score,
    -- Engagement
    ap.hook_rate,
    ap.hold_rate_3s,
    ap.completion_rate,
    ap.funnel_dropoff_rate,
    -- Spend and clicks
    ap.spend,
    ap.CPM,
    ap.clicks,
    ap.CTR,
    ap.CPC,
    -- Conversion
    ap.purchases,
    ap.CVR,
    ap.CPA,
    -- Revenue and ROAS
    rv.gross_revenue,
    rv.net_revenue,
    rv.ROAS,
    rv.breakeven_roas,
    rv.performance_category,
    -- Scalability decision
    CASE
        WHEN rv.ROAS >= rv.breakeven_roas
             AND ap.fatigue_status = 'Low Fatigue'
             THEN 'Scale'
        WHEN rv.ROAS >= rv.breakeven_roas
             AND ap.fatigue_status = 'Medium Fatigue'
             THEN 'Monitor'
        WHEN rv.ROAS < rv.breakeven_roas
             AND ap.fatigue_status = 'Low Fatigue'
             THEN 'Optimise'
        ELSE 'Kill'
    END AS scalability_decision,
	ac.hook_type || ' | ' ||
ac.creative_angle ||  ' | ' ||
ac.copy_tone || ' | ' ||
ac.ad_format || ' | ' ||
CASE WHEN ac.has_ugc = 1 THEN 'UGC'
	ELSE 'Non UGC'
END AS creative_combination
FROM ad_creative ac
JOIN dim_date       d  ON ac.date    = d.date
JOIN products       p  ON ac.product = p.product
JOIN ad_performance ap ON ac.row_id  = ap.row_id
JOIN revenue        rv ON ac.row_id  = rv.row_id;


---- creative combination
SELECT creative_combination
FROM vw_performance_master
LIMIT 10;

-- Verify the view
SELECT COUNT(*) AS total_rows FROM vw_performance_master;
SELECT * FROM vw_performance_master LIMIT 5;
 
---
select count(*)
from vw_performance_master;

--
select count(*)
from ad_performance;


select table_name
from information_schema.tables
where table_schema = 'public'
order by table_name;


--
SELECT COUNT(*) FROM fitpulse_raw_backup;


--
SELECT pg_get_viewdef('vw_performance_master', true);

---
SELECT 
    SUBSTRING(pg_get_viewdef('vw_performance_master', true), 1, 500) AS part1;

--
SELECT 
    SUBSTRING(pg_get_viewdef('vw_performance_master', true), 500, 500) AS part2;

---
SELECT 
    SUBSTRING(pg_get_viewdef('vw_performance_master', true), 1000, 500) AS part3;


--
SELECT row_id, COUNT(*) as cnt
FROM vw_performance_master
GROUP BY row_id
HAVING COUNT(*) > 1
LIMIT 10;

---
SELECT row_id, COUNT(*) as cnt
FROM ad_performance
GROUP BY row_id
HAVING COUNT(*) > 1
LIMIT 5;

--
SELECT row_id, COUNT(*) as cnt
FROM revenue
GROUP BY row_id
HAVING COUNT(*) > 1
LIMIT 5;


--
SELECT COUNT(*) FROM ad_performance;

--
DELETE FROM ad_performance
WHERE performance_id NOT IN (
    SELECT MIN(performance_id)
    FROM ad_performance
    GROUP BY row_id
);

---
SELECT COUNT(*) FROM ad_performance;

--
SELECT COUNT(*) FROM vw_performance_master;

--
SELECT platform,
ROUND(AVG(frequency)::numeric, 2) as avg_frequency
FROM vw_performance_master
GROUP BY platform;


--
SELECT DISTINCT frequency 
FROM vw_performance_master 
LIMIT 20;


---
select sum(reach)
from vw_performance_master ;


-
















