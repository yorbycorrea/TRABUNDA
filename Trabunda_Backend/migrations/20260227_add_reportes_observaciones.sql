-- Safe migration for MySQL/MariaDB: adds reportes.observaciones only if missing
SET @column_exists := (
  SELECT COUNT(*)
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'reportes'
    AND COLUMN_NAME = 'observaciones'
);

SET @ddl := IF(
  @column_exists = 0,
  'ALTER TABLE reportes ADD COLUMN observaciones TEXT NULL AFTER creado_por_nombre',
  'SELECT "reportes.observaciones already exists"'
);

PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
