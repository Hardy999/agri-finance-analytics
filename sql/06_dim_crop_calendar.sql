USE AgriFinance;

IF OBJECT_ID('dbo.dim_crop_calendar', 'U') IS NULL
CREATE TABLE dbo.dim_crop_calendar (
    region_id         INT           NOT NULL,
    region_published  NVARCHAR(50)  NULL,      -- as in the source ('West'); NULL on the 4 borrowed rows
    crop_id           INT           NOT NULL,
    -- The season lives inside this label. WARNING for 5A: 'Maize (Second)'
    -- is the minor season in the south but the ONLY season in the north.
    crop_name         NVARCHAR(50)  NOT NULL,

    -- Dekads: the year in 36 ten-day blocks; dekad 1 = 1-10 January.
    -- sos = start of season (sowing), eos = end of season (harvest);
    -- _s / _e = the window opens / closes.
    sos_s  TINYINT NOT NULL,
    sos_e  TINYINT NOT NULL,
    eos_s  TINYINT NOT NULL,
    eos_e  TINYINT NOT NULL,

    harvest_crosses_year  BIT           NOT NULL,   -- harvest window runs past 31 Dec
    calendar_source       NVARCHAR(100) NOT NULL,   -- 'observed' or 'borrowed: ...'

    -- Composite key: region + season label. No generated number, because
    -- no other table points at a calendar row.
    CONSTRAINT pk_dim_crop_calendar PRIMARY KEY (region_id, crop_name),
    CONSTRAINT fk_dim_crop_calendar_region
        FOREIGN KEY (region_id) REFERENCES dbo.dim_region (region_id),
    CONSTRAINT fk_dim_crop_calendar_crop
        FOREIGN KEY (crop_id) REFERENCES dbo.dim_crop (crop_id),

    CONSTRAINT ck_dim_crop_calendar_dekads CHECK (
        sos_s BETWEEN 1 AND 36 AND sos_e BETWEEN 1 AND 36 AND
        eos_s BETWEEN 1 AND 36 AND eos_e BETWEEN 1 AND 36),

    -- The flag must agree with the numbers: crosses the year exactly when
    -- the harvest window closes on a lower dekad than it opens (34 -> 1).
    CONSTRAINT ck_dim_crop_calendar_wrap CHECK (
        (harvest_crosses_year = 1 AND eos_e <  eos_s) OR
        (harvest_crosses_year = 0 AND eos_e >= eos_s))
);

SELECT * FROM dim_crop_calendar;



SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'dim_crop_calendar'
ORDER BY ORDINAL_POSITION;

SELECT name AS fk_name,
       OBJECT_NAME(parent_object_id)     AS from_table,
       OBJECT_NAME(referenced_object_id) AS to_table
FROM sys.foreign_keys
ORDER BY from_table;

-- CHECK constraints in the whole database.
SELECT name AS check_name, OBJECT_NAME(parent_object_id) AS on_table
FROM sys.check_constraints;