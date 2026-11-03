USE AgriFinance;

IF OBJECT_ID('dbo.dim_unit', 'U') IS NULL
CREATE TABLE dbo.dim_unit (
    unit_id    INT IDENTITY(1,1) NOT NULL,   -- no source ID for units
    unit_name  NVARCHAR(20)      NOT NULL,   -- as published: 'KG', '50 KG', 'Bunch'

    -- NULL = not a weight (100 Tubers, 30 pcs, Bunch): no kg conversion
    -- exists, and inventing one would break Rule 2. 4,946 price rows.
    unit_kg    DECIMAL(9,3)      NULL,

    CONSTRAINT pk_dim_unit PRIMARY KEY (unit_id),
    CONSTRAINT uq_dim_unit_name UNIQUE (unit_name),
    -- A weight of zero or less would make price per kg divide by zero
    -- or go negative. Observed values run 1 to 250.
    CONSTRAINT ck_dim_unit_kg CHECK (unit_kg > 0)
);


SELECT name AS fk_name,
       OBJECT_NAME(parent_object_id)     AS from_table,
       OBJECT_NAME(referenced_object_id) AS to_table
FROM sys.foreign_keys
ORDER BY from_table;

SELECT name AS check_name, OBJECT_NAME(parent_object_id) AS on_table
FROM sys.check_constraints
ORDER BY on_table;
