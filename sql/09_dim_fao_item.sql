-- 09_dim_fao_item.sql
-- One row per FAOSTAT item (8). Links FAOSTAT to dim_crop.
USE AgriFinance;

IF OBJECT_ID('dbo.dim_fao_item', 'U') IS NULL
CREATE TABLE dbo.dim_fao_item (
    -- FAO's own code, kept as TEXT: '0112' and '01520.01' lose their
    -- leading zero as numbers and stop matching FAO (Phase 3 lesson).
    item_code  NVARCHAR(10)  NOT NULL,
    item_name  NVARCHAR(100) NOT NULL,   -- 'Groundnuts, excluding shelled' is the longest
    crop_id    INT           NULL,       -- NULL for groundnuts and cowpeas: not our crops

    CONSTRAINT pk_dim_fao_item PRIMARY KEY (item_code),
    CONSTRAINT fk_dim_fao_item_crop
        FOREIGN KEY (crop_id) REFERENCES dbo.dim_crop (crop_id)
);