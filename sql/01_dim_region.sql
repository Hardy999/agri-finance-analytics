USE AgriFinance;


-- OBJECT_ID returns NULL if no user table ('U') has this name, so running the
-- script twice does nothing the second time, as with 00_create_database.sql.
IF OBJECT_ID('dbo.dim_region', 'U') IS NULL
CREATE TABLE dbo.dim_region (
    -- Surrogate key: a number with no meaning except "this row".
    -- IDENTITY(1,1) = SQL Server numbers the rows itself, from 1, step 1.
    -- (PostgreSQL: GENERATED AS IDENTITY; MySQL: AUTO_INCREMENT.)
    region_id    INT IDENTITY(1,1) NOT NULL,

    -- The region as published: 'ASHANTI', 'BRONG AHAFO'... Longest is 13
    -- characters ('GREATER ACCRA'); 50 leaves room. NVARCHAR stores any
    -- character, matching how we store text elsewhere in this database.
    region_name  NVARCHAR(50) NOT NULL,

    -- Constraints are named so an error message says which rule broke,
    -- instead of a system-generated name like PK__dim_regi__3B2E....
    CONSTRAINT pk_dim_region PRIMARY KEY (region_id),
    -- The surrogate key alone would allow 'ASHANTI' twice; this stops it.
    CONSTRAINT uq_dim_region_name UNIQUE (region_name)
);


SELECT TABLE_CATALOG, TABLE_NAME, COLUMN_NAME, DATA_TYPE,
       CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'dim_region';

SELECT COUNT(*) AS rows_now FROM dbo.dim_region;

-- Should be NULL: proves the table did NOT land in master.
SELECT OBJECT_ID('master.dbo.dim_region', 'U') AS in_master;