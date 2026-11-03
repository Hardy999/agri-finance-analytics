-- 04_dim_commodity.sql
-- One row per WFP commodity. 26 in prices.csv; 6 map to a crop.

USE AgriFinance;

IF OBJECT_ID('dbo.dim_commodity', 'U') IS NULL
CREATE TABLE dbo.dim_commodity (
    -- WFP's own commodity ID, as with markets. One name per ID (checked 31 Oct).
    commodity_id    INT           NOT NULL,
    commodity_name  NVARCHAR(50)  NOT NULL,   -- longest: 'Fish (mackerel, fresh)', 22
    category        NVARCHAR(50)  NOT NULL,   -- WFP's grouping, e.g. 'cereals and tubers'

    -- NULLABLE on purpose: 20 of 26 commodities have no crop (onions, eggs,
    -- imported rice...). NULL here means "not one of our crops", which is true.
    -- load.py must stop if the crosswalk names a crop that dim_crop lacks,
    -- or a typo would load as NULL and look exactly like onions.
    crop_id         INT           NULL,

    CONSTRAINT pk_dim_commodity PRIMARY KEY (commodity_id),
    CONSTRAINT fk_dim_commodity_crop
        FOREIGN KEY (crop_id) REFERENCES dbo.dim_crop (crop_id)
);




SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME IN ('dim_crop', 'dim_commodity')
ORDER BY TABLE_NAME, ORDINAL_POSITION;

SELECT name AS fk_name,
       OBJECT_NAME(parent_object_id)     AS from_table,
       OBJECT_NAME(referenced_object_id) AS to_table
FROM sys.foreign_keys;