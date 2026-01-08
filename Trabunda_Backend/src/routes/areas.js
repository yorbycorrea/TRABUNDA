// src/routes/areas.js
const express = require("express");
const router = express.Router();
const { pool } = require("../db");
const { asyncHandler } = require("../middlewares/asyncHandler");
const { authMiddleware } = require("../middlewares/auth");

function parseFlag(value, fieldName) {
  if (value == undefined) {
    return undefined;
  }
  if (value === true || value === false) {
    return value ? 1 : 0;
  }

  if (value === 1 || value === 0) {
    return value;
  }

  if (value === "1" || value === "0") {
    return Number(value);
  }
  throw new Error(`Valor invalido para ${fieldName}`);
}

// Mapea tipo_reporte -> flag en tabla areas
function flagPorTipo(tipo) {
  switch (tipo) {
    case "APOYO_HORAS":
      return "es_apoyo_horas";
    case "TRABAJO_AVANCE":
      return "es_trabajo_avance";
    case "SANEAMIENTO":
      // por ahora usamos es_conteo_rapido
      return "es_conteo_rapido";
    default:
      return null;
  }
}

/**
 * GET /areas
 * /areas?tipo=APOYO_HORAS | TRABAJO_AVANCE | SANEAMIENTO
 * Si se mandas tipo, devuelve todas las áreas activas.
 */
router.get(
  "/",
  asyncHandler(async (req, res) => {
    const { tipo } = req.query;

    // 1. Caso: No se envía tipo -> Devolver todas las activas
    if (!tipo) {
      const [rows] = await pool.query(
        `SELECT id, nombre, es_apoyo_horas, es_conteo_rapido, es_trabajo_avance, activo 
             FROM areas 
             WHERE activo = 1 
             ORDER BY nombre`
      );
      return res.json(rows);
    }

    // 2. Caso: Se envía tipo -> Validar y filtrar
    const flag = flagPorTipo(tipo);
    if (!flag) {
      return res.status(400).json({
        error: "tipo inválido. Usa: APOYO_HORAS | TRABAJO_AVANCE | SANEAMIENTO",
      });
    }

    // Nota: Aunque flag viene de una función controlada,
    // lo ideal es mapear a nombres de columnas fijos para evitar inyección.
    const [rows] = await pool.query(
      `SELECT id, nombre 
         FROM areas 
         WHERE activo = 1 AND ?? = 1 
         ORDER BY nombre`,
      [flag] // El uso de '??' en librerías como mysql2 escapa nombres de columnas
    );

    return res.json(rows);
  })
);

// ======================================
// POST /areas
// ======================================
router.post("/", async (req, res) => {
  try {
    const {
      nombre,
      es_apoyo_horas,
      es_trabajo_avance,
      es_conteo_rapido,
      activo,
    } = req.body;

    if (!nombre || typeof nombre !== "string" || !nombre.trim()) {
      return res.status(400).json({ error: "nombre es requerido" });
    }

    const flags = {};
    try {
      flags.es_apoyo_horas = parseFlag(es_apoyo_horas, "es_apoyo_horas");
      flags.es_trabajo_avance = parseFlag(
        es_trabajo_avance,
        "es_trabajo_avance"
      );
      flags.es_conteo_rapido = parseFlag(es_conteo_rapido, "es_conteo_rapido");
    } catch (error) {
      return res.status(400).json({ error: error.message });
    }

    const [result] = await pool.query(
      `INSERT INTO areas (nombre, es_apoyo_horas, es_trabajo_avance, es_conteo_rapido, activo)
      VALUES (?,?,?,?,?)`,
      [
        nombre.trim(),
        flags.es_apoyo_horas ?? 0,
        flags.es_trabajo_avance ?? 0,
        flags.es_conteo_rapido ?? 0,
        flags.activo ?? 1,
      ]
    );

    return res.status(201).json({ id: result.insertId });
  } catch (err) {
    console.error("Error al crear area: ", err);
    return res.status(500).json({ error: "Error interno al crear area" });
  }
});

// ============================================
// PUT /areas/:id
// Para actualizar el nombre y las indicaciones con las comprobaciones necesarias
// Edita nombre y flags
// ============================================

router.put("/:id", async (req, res) => {
  try {
    const areaId = Number(req.params.id);
    if (!Number.isInteger(areaId) || areaId <= 0) {
      return res.status(400).json({ error: "id invalido" });
    }

    const {
      nombre,
      es_apoyo_horas,
      es_trabajo_avance,
      es_conteo_rapido,
      activo,
    } = req.body;

    if (!nombre || typeof nombre !== "string" || !nombre.trim()) {
      return res.status(400).json({ error: "nonbre es requerido" });
    }
    let flags;
    try {
      flags = {
        es_apoyo_horas: parseFlag(es_apoyo_horas, "es_apoyo_horas"),
        es_trabajo_avance: parseFlag(es_trabajo_avance, "es_trabajo_avance"),
        es_conteo_rapido: parseFlag(es_conteo_rapido, "es_conteo_rapido"),
        activo: parseFlag(activo, "activo"),
      };
    } catch (error) {
      return res.status(400).json({ error: error.message });
    }

    if (Object.values(flags).some((value) => value === undefined)) {
      return res.status(400).json({
        error:
          "Debes enviar es_apoyo_horas, es_trabajo_avance, es_conteo_rapido y activo",
      });
    }

    const [result] = await pool.query(
      `
      UPDATE areas
      SET nombre = ?, es_apoyo_horas = ?, es_trabajo_avance = ?, es_conteo_rapido = ?, activo = ?
      WHERE id = ?`,
      [
        nombre.trim(),
        flags.es_apoyo_horas,
        flags.es_trabajo_avance,
        flags.es_conteo_rapido,
        flags.activo,
        areaId,
      ]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ error: "Area no encontrada" });
    }

    return res.json({ message: "Area actualizada" });
  } catch (err) {
    console.error("Error al actualizar area:", err);
    return res.status(500).json({ error: "Error interno al actualizar area" });
  }
});

// ===============================================
// PATCH /areas/:id/activar
// ednpoint para activar y desactivar el estado con validacion
// Activa o desactiva una area
// ================================================

router.patch("/:id/activar", async (req, res) => {
  try {
    const areaId = Number(req.params.id);
    if (!Number.isInteger(areaId) || areaId <= 0) {
      return res.status(400).json({ error: "id invalido" });
    }
    let activo;
    try {
      activo = parseFlag(req.body.activo, "activo");
    } catch (error) {
      return res.status(400).json({ error: error.message });
    }
    if (activo === undefined) {
      return res.status(400).json({ error: "activo es requerido" });
    }
    const [result] = await pool.query(
      `UPDATE areas
      SET activo = ?
      WHERE id = ?`,
      [activo, areaId]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ error: "Area no encontrada" });
    }

    return res.json({ message: "Estado actualizado" });
  } catch (err) {
    console.error("Error al actualizar el estado del area:", err);
    return res.status(500).json({
      error: "Error al actualizar el estado del area",
    });
  }
});

router.get("/conteo-rapido", authMiddleware, async (req, res) => {
  try {
    const [rows] = await pool.query(
      `SELECT id, nombre
       FROM areas
       WHERE activo = 1 AND es_conteo_rapido = 1
       ORDER BY nombre`
    );
    res.json({ areas: rows });
  } catch (e) {
    res.status(500).json({ error: "Error cargando áreas", details: String(e) });
  }
});





module.exports = router;
