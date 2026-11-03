-- 14_v_policy_rate_monthly.sql
-- One row per month in dim_date: the policy rate in force on the LAST day
-- of that month (rule agreed 28 Oct, Phase 3 B2). Derived, not published:
-- the Bank sets rates on days, not months.
-- NULL before the first published change (21 Nov 2002) and after the month
-- of the last one (Mar 2026): no rate is assumed for those months.

USE AgriFinance;
GO
-- A view must be the only statement in its batch, hence the GO above.
-- CREATE OR ALTER: creates it the first time, replaces it on a re-run.
CREATE OR ALTER VIEW dbo.v_policy_rate_monthly AS
SELECT d.month_start,
       d.month_end,
       r.policy_rate_pct  AS policy_rate_pct_month_end,
       -- Which published change this month's figure comes from, so every
       -- monthly value traces back to a real Bank of Ghana row.
       r.effective_date   AS rate_effective_date
FROM dbo.dim_date AS d
-- OUTER APPLY runs the inner query once per month. OUTER keeps months where
-- it finds nothing, as NULL, like a LEFT JOIN. CROSS APPLY would silently
-- drop them, the same "hidden gap" problem dim_date exists to prevent.
-- (PostgreSQL / standard SQL: LEFT JOIN LATERAL.)
OUTER APPLY (
    SELECT TOP 1 fr.policy_rate_pct, fr.effective_date
    FROM dbo.fact_rate AS fr
    WHERE fr.effective_date <= d.month_end              -- in force by the last day
      AND d.month_start <= (SELECT MAX(effective_date)   -- stop after the last
                            FROM dbo.fact_rate)          -- published change
    ORDER BY fr.effective_date DESC                      -- the most recent one
) AS r;