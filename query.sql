-- =====================================================================
-- Airline Customer Insights: SQL analysis (PostgreSQL, schema "pipeline")
-- Tables are loaded by Customer_Insights_Pipeline.ipynb
-- =====================================================================

-- ---------- KPI views used by Power BI ----------
CREATE OR REPLACE VIEW pipeline.v_kpi_by_route AS
SELECT s.route,
       COUNT(*) AS responses,
       ROUND(100.0 * AVG(CASE WHEN s.csat_score >= 4 THEN 1.0 WHEN s.csat_score IS NOT NULL THEN 0 END), 1) AS csat_pct,
       ROUND(100.0 * (COUNT(*) FILTER (WHERE s.nps_score >= 9) - COUNT(*) FILTER (WHERE s.nps_score <= 6))
             / NULLIF(COUNT(s.nps_score), 0), 1) AS nps,
       ROUND(AVG(s.ces_score)::numeric, 2) AS avg_ces
FROM pipeline.surveys s
GROUP BY s.route;

CREATE OR REPLACE VIEW pipeline.v_complaints_by_route AS
WITH comp AS (
    SELECT route, COUNT(*) AS complaints,
           ROUND(100.0 * AVG(CASE WHEN contact_count = 1 AND resolved = 'Yes' THEN 1.0 ELSE 0 END), 1) AS fcr_pct,
           ROUND(AVG(resolution_days)::numeric, 1) AS avg_resolution_days
    FROM pipeline.complaints GROUP BY route),
pax AS (
    SELECT route, SUM(passengers) AS passengers FROM pipeline.flights GROUP BY route)
SELECT comp.*, pax.passengers,
       ROUND((1000.0 * comp.complaints / pax.passengers)::numeric, 2) AS complaints_per_1k
FROM comp JOIN pax ON comp.route = pax.route;

-- ---------- Business questions ----------

-- Q1. How many surveys came from each cabin class?
SELECT cabin_class, COUNT(*) AS no_of_surveys
FROM pipeline.surveys
GROUP BY cabin_class
ORDER BY no_of_surveys DESC;

-- Q2. What is the average CSAT score by route?
SELECT route, ROUND(AVG(csat_score)::numeric, 2) AS avg_csat_score
FROM pipeline.surveys
GROUP BY route
ORDER BY avg_csat_score DESC;

-- Q3. CSAT % (top-2 box: scores 4-5) by route
SELECT route,
       ROUND(AVG(CASE WHEN csat_score >= 4 THEN 1
                      WHEN csat_score IS NOT NULL THEN 0 END) * 100, 1) AS csat_pct
FROM pipeline.surveys
GROUP BY route
ORDER BY csat_pct DESC;

-- Q4. NPS by route (% promoters - % detractors)
SELECT route,
       ROUND(100.0 * (SUM(CASE WHEN nps_score >= 9 THEN 1 ELSE 0 END)
                    - SUM(CASE WHEN nps_score <= 6 THEN 1 ELSE 0 END))
             / COUNT(nps_score), 1) AS nps
FROM pipeline.surveys
GROUP BY route
ORDER BY nps DESC;

-- Q5. Average resolution days by complaint type
SELECT issue_type, ROUND(AVG(resolution_days)::numeric, 2) AS avg_resolution_days
FROM pipeline.complaints
GROUP BY issue_type
ORDER BY avg_resolution_days DESC;

-- Q6. Complaints per 1,000 passengers by route (aggregate before joining)
WITH pax AS (SELECT route, SUM(passengers) AS passengers FROM pipeline.flights GROUP BY route),
     cmp AS (SELECT route, COUNT(*) AS complaints FROM pipeline.complaints GROUP BY route)
SELECT p.route,
       ROUND((1000.0 * c.complaints / p.passengers)::numeric, 2) AS complaints_per_1k
FROM pax p JOIN cmp c ON p.route = c.route
ORDER BY complaints_per_1k DESC;

-- Q7. First-contact resolution % by complaint type (worst first)
SELECT issue_type, COUNT(*) AS total_cases,
       ROUND(100.0 * SUM(CASE WHEN contact_count = 1 AND resolved = 'Yes' THEN 1 ELSE 0 END)
             / COUNT(*), 2) AS fcr_pct
FROM pipeline.complaints
GROUP BY issue_type
ORDER BY fcr_pct;

-- Q8. CSAT % by route and cabin (only groups with 30+ surveys)
SELECT route, cabin_class,
       ROUND(AVG(CASE WHEN csat_score >= 4 THEN 1
                      WHEN csat_score IS NOT NULL THEN 0 END) * 100, 1) AS csat_pct,
       COUNT(*) AS total_surveys
FROM pipeline.surveys
GROUP BY route, cabin_class
HAVING COUNT(*) >= 30
ORDER BY csat_pct DESC;

-- Q9. Complaints per month
SELECT DATE_TRUNC('month', open_date) AS month, COUNT(*) AS total_complaints
FROM pipeline.complaints
GROUP BY month
ORDER BY month;

-- Q10. Repeat complainers (more than one case)
SELECT customer_id, COUNT(*) AS total_complaints
FROM pipeline.complaints
GROUP BY customer_id
HAVING COUNT(*) > 1
ORDER BY total_complaints DESC;

-- Q11. Rank routes by CSAT % (window function)
SELECT route, csat_pct,
       RANK() OVER (ORDER BY csat_pct DESC) AS csat_rank
FROM pipeline.v_kpi_by_route;

-- Q12. Each complaint type's share of its route's complaints (window function)
SELECT route, issue_type, COUNT(*) AS complaints,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY route), 1) AS pct_of_route
FROM pipeline.complaints
GROUP BY route, issue_type
ORDER BY route, complaints DESC;
