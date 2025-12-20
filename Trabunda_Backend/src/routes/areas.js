// src/routes/areas.js
const express = require("express");
const router = express.Router();
const { pool } = require("../db");

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
router.get("/", async (req, res) => {
  try {
    const { tipo } = req.query;

    // Si NO hay tipo, traemos todas las activas
    if (!tipo) {
      const [rows] = await pool.query(
        `SELECT id, nombre, es_apoyo_horas, es_conteo_rapido, es_trabajo_avance, activo
         FROM areas
         WHERE activo = 1
         ORDER BY nombre`
      );
      return res.json(rows);
    }

    // Si hay tipo, validamos y filtramos por flag
    const flag = flagPorTipo(tipo);
    if (!flag) {
      return res.status(400).json({
        error: "tipo inválido. Usa: APOYO_HORAS | TRABAJO_AVANCE | SANEAMIENTO",
      });
    }

    const [rows] = await pool.query(
      `SELECT id, nombre
       FROM areas
       WHERE activo = 1 AND ${flag} = 1
       ORDER BY nombre`
    );

    return res.json(rows);
  } catch (err) {
    console.error("Error al listar áreas:", err);
    res.status(500).json({ error: "Error interno al listar áreas" });
  }
});

module.exports = router;
