-- 11_dim_fao_flag.sql
-- One row per FAOSTAT flag (4). Keeps estimated/imputed values identifiable (Rule 2).
USE AgriFinance;

IF OBJECT_ID('dbo.dim_fao_flag', 'U') IS NULL
CREATE TABLE dbo.dim_fao_flag (
    flag_code         NVARCHAR(2)   NOT NULL,   -- 'A', 'E', 'I', 'X'
    flag_description  NVARCHAR(100) NOT NULL,

    CONSTRAINT pk_dim_fao_flag PRIMARY KEY (flag_code)
);