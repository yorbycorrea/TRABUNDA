// src/routes/reportes.js
const express = require("express");
const router = express.Router();
const { pool } = require("../db");
const { authMiddleware } = require("../middlewares/auth");

function esTipoReporteValido(tipo) {
  return ["SANEAMIENTO", "APOYO_HORAS", "TRABAJO_AVANCE"].includes(tipo);
}

function esTurnoValido(turno) {
  return ["Mañana", "Tarde", "Noche", "Día"].includes(turno);
}

// según el tipo_reporte, qué flag de la tabla areas debe estar en 1
function flagParaTipoReporte(tipo) {
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

//
// === POST /reportes → crear cabecera (PROTEGIDO) =======
//
router.post("/", authMiddleware, async (req, res) => {
  try {
    const { fecha, turno, tipo_reporte, area_id, observaciones } = req.body;

    //  user real viene del token
    const creado_por_user_id = req.user.id;

    // 1) Validar campos obligatorios 
    if (!fecha || !turno || !tipo_reporte || !area_id) {
      return res.status(400).json({
        error: "Faltan campos obligatorios: fecha, turno, tipo_reporte, area_id",
      });
    }

    if (!esTurnoValido(turno)) {
      return res.status(400).json({ error: "turno no válido" });
    }

    if (!esTipoReporteValido(tipo_reporte)) {
      return res.status(400).json({ error: "tipo_reporte no válido" });
    }

    // 2) Traer nombre real del usuario desde DB
    const [urows] = await pool.query(
      "SELECT nombre, username FROM users WHERE id = ? AND activo = 1 LIMIT 1",
      [creado_por_user_id]
    );

    if (urows.length === 0) {
      return res.status(401).json({ error: "Usuario inválido o desactivado" });
    }

    const creado_por_nombre = urows[0].nombre || urows[0].username;

    // 3) Validar que el área exista y sea compatible con ese tipo de reporte
    const flag = flagParaTipoReporte(tipo_reporte);
    if (!flag) {
      return res.status(400).json({
        error: "No se pudo determinar el módulo para ese tipo_reporte",
      });
    }

    const [areas] = await pool.query(
      `SELECT id, nombre
       FROM areas
       WHERE id = ? AND ${flag} = 1 AND activo = 1`,
      [area_id]
    );

    if (areas.length === 0) {
      return res.status(400).json({
        error: "El área seleccionada no es válida para este tipo de reporte",
      });
    }

    const area = areas[0];

    // 4) Insertar en reportes
    const [result] = await pool.query(
      `INSERT INTO reportes
       (fecha, turno, tipo_reporte, area, area_id, creado_por_user_id, creado_por_nombre, observaciones)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        fecha,
        turno,
        tipo_reporte,
        area.nombre, // compatibilidad con columna texto
        area_id,
        creado_por_user_id,
        creado_por_nombre,
        observaciones || null,
      ]
    );

    res.status(201).json({
      message: "Reporte creado correctamente",
      reporte_id: result.insertId,
      area_nombre: area.nombre,
      creado_por: { id: creado_por_user_id, nombre: creado_por_nombre },
    });
  } catch (err) {
    console.error("Error al crear reporte:", err);
    res.status(500).json({ error: "Error interno al crear el reporte" });
  }
});

//
// === GET /reportes/:id → cabecera ======================
// (este puede ser público o protegido, tú decides)
//
router.get("/:id", async (req, res) => {
  try {
    const { id } = req.params;

    const [rows] = await pool.query(
      `SELECT
         r.id,
         r.fecha,
         r.turno,
         r.tipo_reporte,
         r.area_id,
         a.nombre       AS area_nombre,
         r.creado_por_user_id,
         r.creado_por_nombre,
         r.observaciones,
         r.creado_en
       FROM reportes r
       LEFT JOIN areas a ON r.area_id = a.id
       WHERE r.id = ?`,
      [id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: "Reporte no encontrado" });
    }

    res.json(rows[0]);
  } catch (err) {
    console.error("Error al obtener reporte:", err);
    res.status(500).json({ error: "Error interno al obtener el reporte" });
  }
});


// =====================================
// GET obtener reportes
// =====================================

// LISTAR REPORTES: GET /reportes
// Filtros (opcionales):
//  - desde=YYYY-MM-DD
//  - hasta=YYYY-MM-DD
//  - tipo=SANEAMIENTO|APOYO_HORAS|TRABAJO_AVANCE
//  - area_id=1
//  - turno=Mañana|Tarde|Noche|Día
//  - creador_id=123   (filtra por r.creado_por_user_id)
//  - q=texto          (busca en observaciones / area_nombre / creado_por_nombre)
// Paginación (opcionales):
//  - page=1
//  - limit=20
// Orden (opcionales, con whitelist):
//  - ordenar=fecha|creado_en
//  - dir=asc|desc
//const { authMiddleware } = require("../middlewares/auth");

router.get("/", authMiddleware, async (req, res) => {
  try {
    const {
      desde,
      hasta,
      tipo,
      area_id,
      turno,
      creador_id,
      q,
      page = 1,
      limit = 20,
      ordenar = "fecha",
      dir = "desc",
    } = req.query;

    // Whitelist de orden
    const camposOrden = new Set(["fecha", "creado_en"]);
    const dirs = new Set(["asc", "desc"]);
    const orderBy = camposOrden.has(ordenar) ? ordenar : "fecha";
    const orderDir = dirs.has(String(dir).toLowerCase()) ? String(dir).toLowerCase() : "desc";

    const pageNum = Math.max(parseInt(page, 10) || 1, 1);
    const limitNum = Math.min(Math.max(parseInt(limit, 10) || 20, 1), 200);
    const offset = (pageNum - 1) * limitNum;

    // Construcción dinámica de filtros
    const where = [];
    const params = [];

    if (desde) {
      where.push("r.fecha >= ?");
      params.push(desde);
    }
    if (hasta) {
      where.push("r.fecha <= ?");
      params.push(hasta);
    }
    if (tipo) {
      where.push("r.tipo_reporte = ?");
      params.push(tipo);
    }
    if (area_id) {
      where.push("r.area_id = ?");
      params.push(area_id);
    }
    if (turno) {
      where.push("r.turno = ?");
      params.push(turno);
    }
    if (creador_id) {
      where.push("r.creado_por_user_id = ?");
      params.push(creador_id);
    }
    if (q) {
      // búsqueda simple en 3 campos
      where.push("(r.observaciones LIKE ? OR a.nombre LIKE ? OR r.creado_por_nombre LIKE ?)");
      params.push(`%${q}%`, `%${q}%`, `%${q}%`);
    }

    const whereSql = where.length ? `WHERE ${where.join(" AND ")}` : "";

    // 1) total para paginación
    const [countRows] = await pool.query(
      `SELECT COUNT(*) AS total
       FROM reportes r
       LEFT JOIN areas a ON a.id = r.area_id
       ${whereSql}`,
      params
    );
    const total = countRows[0]?.total || 0;
    const total_pages = Math.ceil(total / limitNum);

    // 2) datos
    const [rows] = await pool.query(
      `SELECT
         r.id,
         r.fecha,
         r.turno,
         r.tipo_reporte,
         r.area_id,
         a.nombre        AS area_nombre,
         r.creado_por_user_id,
         r.creado_por_nombre,
         r.observaciones,
         r.creado_en
       FROM reportes r
       LEFT JOIN areas a ON a.id = r.area_id
       ${whereSql}
       ORDER BY ${orderBy} ${orderDir}, r.id ${orderDir}
       LIMIT ? OFFSET ?`,
      [...params, limitNum, offset]
    );

    return res.json({
      page: pageNum,
      limit: limitNum,
      total,
      total_pages,
      items: rows,
    });
  } catch (err) {
    console.error("Error al listar reportes:", err);
    return res.status(500).json({ error: "Error interno al listar reportes" });
  }
});

module.exports = router;
