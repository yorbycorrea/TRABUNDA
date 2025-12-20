-- =========================================================
-- 0. Crear BASE DE DATOS
-- =========================================================
CREATE DATABASE IF NOT EXISTS trabunda
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE trabunda;

-- =========================================================
-- 1. Tabla TRABAJADORES
--    Maestro de personal (todos los trabajadores de la planta)
-- =========================================================
CREATE TABLE IF NOT EXISTS trabajadores (
  id INT AUTO_INCREMENT PRIMARY KEY,
  codigo VARCHAR(50) NOT NULL UNIQUE,          -- Código que usas en la app / tarjetas
  nombre_completo VARCHAR(255) NOT NULL,
  dni VARCHAR(20) NULL,
  sexo ENUM('M','F') NULL,                     -- Cambiar a VARCHAR(10) si luego quieres más opciones

  activo TINYINT(1) DEFAULT 1,                 -- 1 = activo, 0 = ya no labora
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP NULL
) ENGINE=InnoDB;

CREATE INDEX idx_trabajadores_nombre
  ON trabajadores (nombre_completo);

-- =========================================================
-- 2. Tabla REPORTES (cabecera)
--    Una fila por reporte (saneamiento, apoyo por horas, avance)
-- =========================================================
CREATE TABLE IF NOT EXISTS reportes (
  id INT AUTO_INCREMENT PRIMARY KEY,

  fecha DATE NOT NULL,
  turno ENUM('Mañana', 'Tarde', 'Noche', 'Día') NOT NULL,

  -- Tipo de reporte según el flujo:
  --   SANEAMIENTO       -> reporte del rol Saneamiento
  --   APOYO_HORAS       -> apoyos por horas (rol planillero)
  --   TRABAJO_AVANCE    -> pago por kilos / avance
  tipo_reporte ENUM('SANEAMIENTO', 'APOYO_HORAS', 'TRABAJO_AVANCE') NOT NULL,

  area VARCHAR(100) NOT NULL,                  -- Ej: 'SANEAMIENTO', 'ANILLAS', 'FILETE', etc.

  creado_por_user_id VARCHAR(100) NOT NULL,    -- id del usuario logueado en tu app
  creado_por_nombre VARCHAR(255) NOT NULL,     -- nombre visible (Curay Floriano Luis Martin)

  observaciones TEXT NULL,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE INDEX idx_reportes_fecha_tipo
  ON reportes (fecha, tipo_reporte);

CREATE INDEX idx_reportes_area
  ON reportes (area);

-- =========================================================
-- 3. Tabla CUADRILLAS
--    Agrupa trabajadores dentro de un reporte (sobre todo en TRABAJO_AVANCE)
-- =========================================================
CREATE TABLE IF NOT EXISTS cuadrillas (
  id INT AUTO_INCREMENT PRIMARY KEY,
  reporte_id INT NOT NULL,

  nombre VARCHAR(100) NOT NULL,         -- Ej: 'Cuadrilla A', 'Saneamiento', 'Fileteros 1'
  area VARCHAR(100) NOT NULL,           -- Repetimos área para filtros rápidos

  kilos DECIMAL(10,2) NULL,             -- Kilos totales de la cuadrilla (si aplican)
  hora_inicio TIME NULL,
  hora_fin TIME NULL,

  FOREIGN KEY (reporte_id) REFERENCES reportes(id)
    ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE INDEX idx_cuadrillas_reporte
  ON cuadrillas (reporte_id);

-- =========================================================
-- 4. Tabla LINEAS_REPORTE
--    Detalle por trabajador (se usa para todos los tipos de reporte)
-- =========================================================
CREATE TABLE IF NOT EXISTS lineas_reporte (
  id INT AUTO_INCREMENT PRIMARY KEY,

  reporte_id INT NOT NULL,
  trabajador_id INT NOT NULL,                   -- FK a trabajadores
  cuadrilla_id INT NULL,                        -- Si pertenece a una cuadrilla (avance, saneamiento agrupado, etc.)

  -- Snapshot de datos del trabajador (histórico)
  trabajador_codigo VARCHAR(50) NOT NULL,
  trabajador_nombre VARCHAR(255) NOT NULL,

  -- Para reportes por HORAS (SANEAMIENTO y APOYO_HORAS)
  horas DECIMAL(5,2) NULL,                      -- Total de horas en el turno
  hora_inicio TIME NULL,
  hora_fin TIME NULL,

  -- Para reportes por AVANCE (TRABAJO_AVANCE)
  kilos DECIMAL(10,2) NULL,                     -- Kilos asignados al trabajador

  labores TEXT NULL,                            -- Descripción de tareas / labores

  FOREIGN KEY (reporte_id) REFERENCES reportes(id)
    ON DELETE CASCADE,
  FOREIGN KEY (trabajador_id) REFERENCES trabajadores(id)
    ON DELETE RESTRICT,
  FOREIGN KEY (cuadrilla_id) REFERENCES cuadrillas(id)
    ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE INDEX idx_lineas_reporte_reporte
  ON lineas_reporte (reporte_id);

CREATE INDEX idx_lineas_reporte_trabajador
  ON lineas_reporte (trabajador_id);
  
-- CAMBIOS (AGREGUE AREAS CON RED FLAG )

USE trabunda;

-- ============================================
-- NUEVA TABLA: AREAS
--  - Una sola tabla para todas las áreas
--  - Flags indican en qué módulo se usa
-- ============================================
CREATE TABLE IF NOT EXISTS areas (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,

  -- Banderas (flags) para saber en qué módulo se usa
  es_apoyo_horas     TINYINT(1) DEFAULT 0,  -- 1 = se usa en APOYOS POR HORAS
  es_conteo_rapido   TINYINT(1) DEFAULT 0,  -- 1 = se usa en CONTEO RÁPIDO
  es_trabajo_avance  TINYINT(1) DEFAULT 0,  -- 1 = se usa en TRABAJO POR AVANCE

  activo TINYINT(1) DEFAULT 1,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE INDEX idx_areas_modulos
  ON areas (es_apoyo_horas, es_conteo_rapido, es_trabajo_avance, nombre);

-- Conectamos reportes con areas

-- ============================================
-- AÑADIR area_id A REPORTES
-- ============================================
ALTER TABLE reportes
  ADD COLUMN area_id INT NULL AFTER tipo_reporte;

ALTER TABLE reportes
  ADD CONSTRAINT fk_reportes_areas
  FOREIGN KEY (area_id) REFERENCES areas(id);


-- Rellenamos la tabla areas

