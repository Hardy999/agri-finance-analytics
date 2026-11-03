USE AgriFinance;

IF OBJECT_ID('dbo.fact_price', 'U') IS NULL
CREATE TABLE dbo.fact_price (
    -- The five key columns. Remove any one and legitimate rows collide.
    market_id     INT           NOT NULL,
    commodity_id  INT           NOT NULL,
    month_start   DATE          NOT NULL,
    unit_id       INT           NOT NULL,
    price_type    NVARCHAR(10)  NOT NULL,   -- 'Wholesale' / 'Retail': no attributes, so a column, not a table

    price_flag    NVARCHAR(20)  NOT NULL,   -- WFP: 'actual', 'aggregate', 'actual,aggregate' (410 rows, kept as published)

    -- The measure. Cedis (GHS in all rows, so the currency column was dropped
    -- and the unit moved into the name). At most 2 decimals: stored exactly.
    price_ghs     DECIMAL(12,2) NOT NULL,

    -- Phase 3 flags: marked, never dropped (Rule 0).
    outlier_ratio   FLOAT  NULL,   -- Python's 64-bit value, stored without rounding
    outlier_flag    BIT    NULL,   -- NULL = not tested (38 rows). Not the same as 0.
    series_suspect  BIT    NOT NULL,   -- P8: cassava wholesale 2019+ (473 rows)
    unit_suspect    BIT    NOT NULL,   -- per-kg price under a bag unit (15 rows)

    CONSTRAINT pk_fact_price
        PRIMARY KEY (market_id, commodity_id, month_start, unit_id, price_type),
    CONSTRAINT fk_fact_price_market
        FOREIGN KEY (market_id)    REFERENCES dbo.dim_market (market_id),
    CONSTRAINT fk_fact_price_commodity
        FOREIGN KEY (commodity_id) REFERENCES dbo.dim_commodity (commodity_id),
    CONSTRAINT fk_fact_price_date
        FOREIGN KEY (month_start)  REFERENCES dbo.dim_date (month_start),
    CONSTRAINT fk_fact_price_unit
        FOREIGN KEY (unit_id)      REFERENCES dbo.dim_unit (unit_id),

    CONSTRAINT ck_fact_price_type CHECK (price_type IN ('Wholesale', 'Retail')),
    CONSTRAINT ck_fact_price_flag CHECK (price_flag IN ('actual', 'aggregate', 'actual,aggregate'))
);

SELECT * FROM dbo.fact_price;



