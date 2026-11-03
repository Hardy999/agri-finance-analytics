-- 03_dim_crop.sql
-- One row per crop: the six crops of the Phase 3 crosswalk (X2).
-- Shared by dim_commodity (prices), FAOSTAT items and dim_crop_calendar,
-- so the link between price, yield and harvest window exists once.

USE AgriFinance;

IF OBJECT_ID('dbo.dim_crop', 'U') IS NULL
CREATE TABLE dbo.dim_crop (
    -- No source ID exists for a crop: the names are our own labels.
    -- So we generate the key, as for dim_region.
    crop_id    INT IDENTITY(1,1) NOT NULL,
    crop_name  NVARCHAR(20)      NOT NULL,   -- 'maize', 'millet', ... as in all three files

    CONSTRAINT pk_dim_crop PRIMARY KEY (crop_id),
    -- The generated key alone would allow 'maize' twice.
    CONSTRAINT uq_dim_crop_name UNIQUE (crop_name)
);