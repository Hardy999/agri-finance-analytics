-- 10_dim_fao_element.sql
-- One row per FAOSTAT element (3). The unit lives here, once per element.
USE AgriFinance;

IF OBJECT_ID('dbo.dim_fao_element', 'U') IS NULL
CREATE TABLE dbo.dim_fao_element (
    element_code  INT           NOT NULL,   -- 5312, 5412, 5510: no leading zeros, so a number is safe
    element_name  NVARCHAR(50)  NOT NULL,   -- 'Area harvested', 'Yield', 'Production'
    unit          NVARCHAR(10)  NOT NULL,   -- 'ha', 'kg/ha', 't'

    CONSTRAINT pk_dim_fao_element PRIMARY KEY (element_code)
);