-- 05_dim_date.sql
-- One row per month, Jan 2002 - Dec 2026 (300 rows), generated, not loaded.
-- The calendar must be complete on its own, so months with no prices
-- show as gaps instead of disappearing.

USE AgriFinance;

IF OBJECT_ID('dbo.dim_date', 'U') IS NULL
CREATE TABLE dbo.dim_date (
    month_start    DATE         NOT NULL,   -- key; matches prices.csv 'month' (1st of month)
    month_end      DATE         NOT NULL,   -- last day: the policy-rate rule uses it
    calendar_year  SMALLINT     NOT NULL,   -- not 'year': YEAR() is a T-SQL function
    month_number   TINYINT      NOT NULL,   -- 1-12. TINYINT = 0-255, 1 byte
    month_name     NVARCHAR(10) NOT NULL,   -- 'January' ... 'September' is the longest

    CONSTRAINT pk_dim_date PRIMARY KEY (month_start),
    -- Every key must be the 1st. A '2006-01-15' would match no price row.
    CONSTRAINT ck_dim_date_first_of_month CHECK (DAY(month_start) = 1)
);
GO
-- GO is not T-SQL. It tells SSMS "send everything above as one batch,
-- then start a new one". The table must exist before the batch that fills it.

-- Fill only if empty, so re-running the script never duplicates months
-- (the primary key would reject them anyway, with an error).
IF NOT EXISTS (SELECT 1 FROM dbo.dim_date)
BEGIN
    -- Recursive CTE: start at Jan 2002, then keep adding one month to the
    -- previous row until Dec 2026.
    WITH months AS (
        SELECT CAST('2002-01-01' AS DATE) AS month_start
        UNION ALL
        SELECT DATEADD(MONTH, 1, month_start)
        FROM months
        WHERE month_start < '2026-12-01'
    )
    INSERT INTO dbo.dim_date
        (month_start, month_end, calendar_year, month_number, month_name)
    SELECT month_start,
           EOMONTH(month_start),            -- last day of that month
           YEAR(month_start),
           MONTH(month_start),
           DATENAME(MONTH, month_start)     -- language of the server: 'January'
    FROM months
    -- SQL Server stops a recursive CTE after 100 steps by default, with an
    -- error. 300 months needs 299 steps, so the limit is raised.
    OPTION (MAXRECURSION 300);
END





SELECT COUNT(*) AS months, MIN(month_start) AS first_month, MAX(month_start) AS last_month
FROM dbo.dim_date;

SELECT *
FROM dbo.dim_date
WHERE month_start IN ('2002-11-01', '2006-01-01', '2023-07-01', '2024-02-01')
ORDER BY month_start;