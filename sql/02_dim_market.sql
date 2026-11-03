USE Agrifinance; 



IF OBJECT_ID('dbo.dim_market', 'U') IS NULL
CREATE TABLE dbo.dim_market (
    -- WFP's own market ID, used as our key (no IDENTITY). With IDENTITY,
    -- SQL Server would number rows 1-20 itself and refuse WFP's 209.
    market_id      INT           NOT NULL,

    market_name    NVARCHAR(50)  NOT NULL,   -- 'market' in markets.csv

    -- Points at dim_region. NOT NULL is the guard that matters: a foreign
    -- key ignores NULLs, so without it a failed region lookup would load
    -- a market with no region and no error.
    region_id      INT           NOT NULL,

    district_name  NVARCHAR(100) NOT NULL,   -- 'admin2' in markets.csv, as published

    -- DECIMAL stores 5.55 exactly. FLOAT stores the nearest binary fraction,
    -- which can come back as 5.5499999. Data has 2 decimals (~1 km);
    -- (9,6) holds that exactly and allows a finer source later.
    latitude       DECIMAL(9,6)  NOT NULL,
    longitude      DECIMAL(9,6)  NOT NULL,

    -- 1 = market has 3-8 years of data (Phase 1 Rule A). Analyses needing
    -- an unbroken 2006-2023 series filter on short_panel = 0.
    short_panel    BIT           NOT NULL,

    CONSTRAINT pk_dim_market PRIMARY KEY (market_id),
    CONSTRAINT fk_dim_market_region
        FOREIGN KEY (region_id) REFERENCES dbo.dim_region (region_id)
);




SELECT COLUMN_NAME, DATA_TYPE, NUMERIC_PRECISION, NUMERIC_SCALE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'dim_market'
ORDER BY ORDINAL_POSITION;

-- Lists foreign keys: which table points at which.
SELECT name AS fk_name,
       OBJECT_NAME(parent_object_id)     AS from_table,
       OBJECT_NAME(referenced_object_id) AS to_table
FROM sys.foreign_keys;