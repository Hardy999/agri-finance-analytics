-- 90_check_row_counts.sql
-- Exact row count of every table, against the expected values.
-- COUNT(*) on each table, not sys.partitions: Microsoft documents that
-- view's row figure as APPROXIMATE, and an approximate count is not a check.
USE AgriFinance;

SELECT tbl, actual, expected,
       CASE WHEN actual = expected THEN 'ok' ELSE '*** MISMATCH ***' END AS result
FROM (
          SELECT 'dim_region'        AS tbl, COUNT(*) AS actual,    10 AS expected FROM dbo.dim_region
    UNION ALL SELECT 'dim_market',          COUNT(*),    20 FROM dbo.dim_market
    UNION ALL SELECT 'dim_crop',            COUNT(*),     6 FROM dbo.dim_crop
    UNION ALL SELECT 'dim_commodity',       COUNT(*),    26 FROM dbo.dim_commodity
    UNION ALL SELECT 'dim_unit',            COUNT(*),    18 FROM dbo.dim_unit
    UNION ALL SELECT 'dim_date',            COUNT(*),   300 FROM dbo.dim_date
    UNION ALL SELECT 'dim_crop_calendar',   COUNT(*),    38 FROM dbo.dim_crop_calendar
    UNION ALL SELECT 'dim_fao_item',        COUNT(*),     8 FROM dbo.dim_fao_item
    UNION ALL SELECT 'dim_fao_element',     COUNT(*),     3 FROM dbo.dim_fao_element
    UNION ALL SELECT 'dim_fao_flag',        COUNT(*),     4 FROM dbo.dim_fao_flag
    UNION ALL SELECT 'fact_price',          COUNT(*), 37676 FROM dbo.fact_price
    UNION ALL SELECT 'fact_yield',          COUNT(*),  1536 FROM dbo.fact_yield
    UNION ALL SELECT 'fact_rate',           COUNT(*),   130 FROM dbo.fact_rate
) AS c
ORDER BY tbl;



