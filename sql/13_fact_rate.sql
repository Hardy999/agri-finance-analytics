-- 13_fact_rate.sql
-- Grain (agreed 28 Oct): one row per effective date, as published by the
-- Bank of Ghana. 130 rates, 21 Nov 2002 - 18 Mar 2026.
-- Not linked to dim_date: these are days, dim_date is months. The monthly
-- rate is a separate view built from this table (next script).

USE AgriFinance;

IF OBJECT_ID('dbo.fact_rate', 'U') IS NULL
CREATE TABLE dbo.fact_rate (
    effective_date   DATE          NOT NULL,   -- the key: 130 distinct in 130 rows
    policy_rate_pct  DECIMAL(5,2)  NOT NULL,   -- percent per year; 12.5 - 30.0 observed

    -- NOT a key and deliberately NOT unique: one number appears twice (129
    -- distinct in 130 rows). A UNIQUE constraint here would reject a real row.
    meeting_no       INT           NOT NULL,

    -- As published. Mostly 'November 20 – 21, 2002' with an en dash, but 3 rows
    -- use a hyphen and 1 is a single day ('August 17, 2022 (Emergency)').
    -- Anything that parses this must handle all three forms.
    mpc_dates        NVARCHAR(50)  NOT NULL,

    CONSTRAINT pk_fact_rate PRIMARY KEY (effective_date),
    CONSTRAINT ck_fact_rate_positive CHECK (policy_rate_pct > 0)
);



SELECT COLUMN_NAME, DATA_TYPE, NUMERIC_PRECISION, NUMERIC_SCALE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'fact_rate'
ORDER BY ORDINAL_POSITION;

SELECT COUNT(*) AS tables_in_db
FROM sys.tables;