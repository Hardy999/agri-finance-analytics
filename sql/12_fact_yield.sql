-- 12_fact_yield.sql
-- Grain (agreed 28 Oct): one value per element, item and year. Ghana, national.
-- 1,536 rows = 3 elements x 8 items x 64 years (1961-2024); key unique (checked 31 Oct).
-- Joins to prices only through crop and year: no market, no region.
USE AgriFinance;

IF OBJECT_ID('dbo.fact_yield', 'U') IS NULL
CREATE TABLE dbo.fact_yield (
    element_code  INT           NOT NULL,
    item_code     NVARCHAR(10)  NOT NULL,
    -- A plain year, not a key to dim_date: dim_date is monthly from 2002;
    -- FAOSTAT is yearly from 1961.
    fao_year      SMALLINT      NOT NULL,

    -- WARNING: no single unit. ha, kg/ha or t depending on element_code.
    -- Never SUM or AVG this without filtering to ONE element.
    -- NULL on 150 cowpea rows: FAO published nothing. Kept, not dropped.
    value         DECIMAL(15,2) NULL,

    flag_code     NVARCHAR(2)   NULL,   -- NULL on the same blank cowpea rows
    note          NVARCHAR(100) NULL,   -- 'Unofficial figure' on 34 rows

    CONSTRAINT pk_fact_yield PRIMARY KEY (element_code, item_code, fao_year),
    CONSTRAINT fk_fact_yield_element
        FOREIGN KEY (element_code) REFERENCES dbo.dim_fao_element (element_code),
    CONSTRAINT fk_fact_yield_item
        FOREIGN KEY (item_code)    REFERENCES dbo.dim_fao_item (item_code),
    CONSTRAINT fk_fact_yield_flag
        FOREIGN KEY (flag_code)    REFERENCES dbo.dim_fao_flag (flag_code),
    -- FAOSTAT starts in 1961. No upper bound, so next year's release still loads.
    CONSTRAINT ck_fact_yield_year CHECK (fao_year >= 1961)
);




SELECT name AS fk_name,
       OBJECT_NAME(parent_object_id)     AS from_table,
       OBJECT_NAME(referenced_object_id) AS to_table
FROM sys.foreign_keys
ORDER BY from_table;

SELECT name AS check_name, OBJECT_NAME(parent_object_id) AS on_table
FROM sys.check_constraints
ORDER BY on_table;