// src/routes/reportes.js
const express = require("express");
const router = express.Router();
const { pool } = require("../db");
const { authMiddleware } = require("../middlewares/auth");
const PDFDocument = require("pdfkit");
const fs = require("fs");
const path = require("path");
const { chromium } = require("playwright");
const ExcelJS = require('exceljs');
const { getTrabajadorPorCodigo } = require("../services/trabajadorApi");
const { resolveTrabajadorLookup } = require("../services/trabajadorLookup");

//const { width } = require("pdfkit/js/page");

/* =========================
   Helpers
========================= */

function esTipoReporteValido(tipo) {
  return ["SANEAMIENTO", "APOYO_HORAS", "TRABAJO_AVANCE", "CONTEO_RAPIDO"].includes(
    tipo
  );
}

function normalizarTurno(turno) {
  if (!turno) return turno;
  const t = String(turno).trim().toLowerCase();
  const tSinTilde = t.normalize("NFD").replace(/\p{Diacritic}/gu, "");
  if (tSinTilde === "dia") return "Dia";
  if (t === "noche") return "Noche";
  return String(turno).trim();
}

function esTurnoValido(turno) {
  const t = normalizarTurno(turno);
  return ["Dia", "Noche"].includes(t);
}

function nombreTipoReporte(tipo) {
  switch (tipo) {
    case "SANEAMIENTO":
      return "Saneamiento";
    case "APOYO_HORAS":
      return "Apoyo por horas";
    case "TRABAJO_AVANCE":
      return "Trabajo por avance";
    case "CONTEO_RAPIDO":
      return "Conteo rapido";
    default:
      return tipo || "Reporte";
  }
}

function textoSeguro(valor) {
  if (valor === null || valor === undefined || valor === "") return "-";
  return String(valor);
}

function timeToMinutes(timeValue) {
  if (timeValue === null || timeValue === undefined) return null;
  const [hhRaw, mmRaw] = String(timeValue).split(":");
  const hh = Number(hhRaw);
  const mm = Number(mmRaw);

  if (!Number.isInteger(hh) || !Number.isInteger(mm)) return null;
  if (hh < 0 || hh > 23 || mm < 0 || mm > 59) return null;

  return hh * 60 + mm;
}

function calcularDiferenciaMinutos(horaInicio, horaFin) {
  const inicioMin = timeToMinutes(horaInicio);
  const finMinOriginal = timeToMinutes(horaFin);

  if (inicioMin === null || finMinOriginal === null) {
    throw new Error("Formato de hora inválido");
  }

  let finMin = finMinOriginal;
  if (finMin < inicioMin) {
    finMin += 24 * 60;
  }

  return finMin - inicioMin;
}

function calcularTotalHoras(horaInicio, horaFin) {
  const totalMin = calcularDiferenciaMinutos(horaInicio, horaFin);

  if (totalMin <= 0) {
    throw new Error("hora_fin debe ser mayor que hora_inicio");
  }

  if (totalMin > 18 * 60) {
    throw new Error(
      "Verifica la hora de salida. El turno no puede superar mas de  18 horas"
    );
  }

  return totalMin / 60;
}

function formatearTotalHorasParaPdf(linea) {
  const horaInicio = linea?.hora_inicio;
  const horaFin = linea?.hora_fin;

  if (horaInicio && horaFin) {
    try {
      return calcularTotalHoras(horaInicio, horaFin).toFixed(2);
    } catch (_) {
      // fallback al valor persistido si no se puede recalcular
    }
  }

  const horasPersistidas = Number(linea?.horas);
  if (Number.isFinite(horasPersistidas)) {
    return Math.abs(horasPersistidas).toFixed(2);
  }

  return linea?.horas ?? "";
}

async function hidratarTrabajadoresPorCodigo(items = [], dbPool = pool) {
  if (!Array.isArray(items) || items.length === 0) return [];

  const codigos = [...new Set(
    items
      .map((item) => String(item?.trabajador_codigo ?? "").trim())
      .filter(Boolean)
  )];

  if (codigos.length === 0) return items;

  const placeholders = codigos.map(() => "?").join(",");
  const [rows] = await dbPool.query(
    `SELECT TRIM(codigo) AS codigo, nombre_completo, dni
     FROM trabajadores
     WHERE TRIM(codigo) IN (${placeholders})`,
    codigos
  );

  const trabajadoresByCodigo = new Map(
    rows.map((row) => [String(row.codigo ?? "").trim(), row])
  );

  return items.map((item) => {
    const codigo = String(item?.trabajador_codigo ?? "").trim();
    const trabajador = trabajadoresByCodigo.get(codigo);
    if (!trabajador) return item;

    return {
      ...item,
      trabajador_codigo: codigo || item?.trabajador_codigo,
      trabajador_nombre:
        String(item?.trabajador_nombre ?? "").trim() ||
        trabajador.nombre_completo ||
        item?.trabajador_nombre,
      trabajador_documento:
        item?.trabajador_documento ?? trabajador.dni ?? null,
    };
  });
}





function agregarFilaTabla(doc, y, columnas) {
  const alturaFila = 18;
  const margenInferior = doc.page.height - doc.page.margins.bottom;
  if (y + alturaFila > margenInferior) {
    doc.addPage();
    return agregarFilaTabla(doc, doc.y, columnas);
  }

  columnas.forEach((columna) => {
    doc.text(columna.texto, columna.x, y, {
      width: columna.ancho,
      align: columna.align || "left",
    });
  });
  return y + alturaFila;
}

function renderTablaHoras(doc, lineas) {
  doc.fontSize(12).text("Detalle por trabajador", { underline: true });
  doc.moveDown(0.5);

  const inicioX = doc.page.margins.left;
  const columnas = [
    { titulo: "Trabajador", x: inicioX, ancho: 200 },
    { titulo: "Cuadrilla", x: inicioX + 230, ancho: 140 },
    { titulo: "Kilos", x: inicioX + 380, ancho: 60, align: "right" },
    { titulo: "Labores", x: inicioX + 450, ancho: 100 },
  ];

  let y = doc.y;

  y = agregarFilaTabla(
    doc,
    y,
    columnas.map((c) => ({
      texto: c.titulo,
      x: c.x,
      ancho: c.ancho,
      align: c.align,
    }))
  );

  doc
    .moveTo(inicioX, y - 4)
    .lineTo(doc.page.width - doc.page.margins.right, y - 4)
    .stroke();

  lineas.forEach((linea) => {
    y = agregarFilaTabla(doc, y, [
      {
        texto: textoSeguro(linea.trabajador_nombre),
        x: columnas[0].x,
        ancho: columnas[0].ancho,
      },
      {
        texto: textoSeguro(linea.cuadrilla_nombre),
        x: columnas[1].x,
        ancho: columnas[1].ancho,
      },
      {
        texto: textoSeguro(linea.kilos),
        x: columnas[2].x,
        ancho: columnas[2].ancho,
        align: "right",
      },
      {
        texto: textoSeguro(linea.labores),
        x: columnas[3].x,
        ancho: columnas[3].ancho,
      },
    ]);
  });
}

function sanitizarObservaciones(rawObservaciones) {
  if (rawObservaciones === undefined) {
    return { provided: false, value: undefined };
  }

  const texto = String(rawObservaciones ?? '').trim();

  if (!texto) {
    return { provided: true, value: null };
  }

  const maxLength = 2000;
  if (texto.length > maxLength) {
    const error = new Error(`Las observaciones no pueden exceder ${maxLength} caracteres`);
    error.code = 'OBSERVACIONES_TOO_LONG';
    throw error;
  }

  return { provided: true, value: texto };
}

function flagParaTipoReporte(tipo) {
  switch (tipo) {
    case "APOYO_HORAS":
      return "es_apoyo_horas";
    case "TRABAJO_AVANCE":
      return "es_trabajo_avance";
    case "CONTEO_RAPIDO":
      return "es_conteo_rapido";
    // SANEAMIENTO no usa area_id (NO validar)
    default:
      return null;
  }

  


}

function tipoTrabajoAvanceValido(tipo) {
  return ["RECEPCION", "FILETEADO", "APOYO_RECEPCION"].includes(String(tipo || "").trim());
}



/**
 * ✅ Recalcula estado del reporte según pendientes
 * - APOYO_HORAS: pendiente si existe linea con hora_fin NULL
 * - SANEAMIENTO: pendiente si existe linea con hora_fin NULL o labores vacías
 * Si pendientes=0 => CERRADO + cerrado_en=NOW()
 * Si pendientes>0 => ABIERTO + cerrado_en=NULL
 */
async function recalcularEstadoReporte(reporteId) {
  const [repRows] = await pool.query(
    "SELECT tipo_reporte FROM reportes WHERE id = ? LIMIT 1",
    [reporteId]
  );
  if (!repRows.length) return { pendientes: 0, estado: null };

  const tipo = repRows[0].tipo_reporte;

  let sql = null;
  if (tipo === "APOYO_HORAS") {
    sql = `
      SELECT COUNT(*) AS cnt
      FROM lineas_reporte
      WHERE reporte_id = ?
        AND hora_fin IS NULL
    `;
  } else if (tipo === "SANEAMIENTO") {
    sql = `
      SELECT COUNT(*) AS cnt
      FROM lineas_reporte
      WHERE reporte_id = ?
        AND (
          hora_fin IS NULL
          OR labores IS NULL
          OR TRIM(labores) = ''
        )
    `;
  } else {
    // otros tipos: por ahora no recalculamos aquí
    return { pendientes: 0, estado: null };
  }

  const [pRows] = await pool.query(sql, [reporteId]);
  const pendientes = Number(pRows[0]?.cnt ?? 0);

  const nuevoEstado = pendientes === 0 ? "CERRADO" : "ABIERTO";

  await pool.query(
    `UPDATE reportes
     SET estado = ?,
         cerrado_en = CASE WHEN ? = 'CERRADO' THEN NOW() ELSE NULL END
     WHERE id = ?`,
    [nuevoEstado, nuevoEstado, reporteId]
  );

  return { pendientes, estado: nuevoEstado };
}

/* ===========================================================
   🔥 ORDEN IMPORTANTE (específicas primero)
=========================================================== */



/* ======================================
   PATCH /reportes/:id/observaciones
====================================== */
router.patch("/:id/observaciones", authMiddleware, async (req, res) => {
  try {
    const { id } = req.params;

    if (process.env.NODE_ENV !== "test") {
      console.log(
        JSON.stringify(
          {
            type: "patch_observaciones_request",
            method: req.method,
            url: `${req.protocol}://${req.get("host")}${req.originalUrl}`,
            params: req.params,
            body: req.body,
            id_recibido: id,
            observaciones_recibidas: req.body?.observaciones,
          },
          null,
          2
        )
      );
    }

    const [rows] = await pool.query(
      "SELECT id, tipo_reporte, creado_por_user_id FROM reportes WHERE id = ? LIMIT 1",
      [id]
    );

    if (!rows.length) {
      return res.status(404).json({ error: "Reporte no encontrado" });
    }

    const reporte = rows[0];
    if (!["APOYO_HORAS", "SANEAMIENTO"].includes(reporte.tipo_reporte)) {
      return res.status(400).json({
        error: "observaciones solo aplica para APOYO_HORAS y SANEAMIENTO",
      });
    }

    const role =
      Array.isArray(req.user.roles) && req.user.roles.length
        ? req.user.roles[0]
        : undefined;

    if (role !== "ADMINISTRADOR" && reporte.creado_por_user_id !== req.user.id) {
      return res.status(403).json({ error: "No autorizado" });
    }

    let observacionesSanitizadas;
    try {
      observacionesSanitizadas = sanitizarObservaciones(req.body?.observaciones);
    } catch (error) {
      if (error?.code === "OBSERVACIONES_TOO_LONG") {
        return res.status(400).json({ error: error.message });
      }
      throw error;
    }

    if (!observacionesSanitizadas.provided) {
      return res.status(400).json({
        error: "Debes enviar el campo observaciones",
      });
    }

    await pool.query(
      "UPDATE reportes SET observaciones = ? WHERE id = ?",
      [observacionesSanitizadas.value, id]
    );

    return res.json({
      message: "Observaciones actualizadas",
      reporte_id: Number(id),
      observaciones: observacionesSanitizadas.value,
    });
  } catch (err) {
    console.error("Error al actualizar observaciones:", err);
    return res.status(500).json({ error: "Error interno al actualizar observaciones" });
  }
});


/* ========================================
   GET /reportes/apoyo-horas/open
======================================== */
router.get("/apoyo-horas/open", authMiddleware, async (req, res) => {
  try {
    const userId = req.user.id;
    const turnoRaw = req.query.turno;
    const turno = normalizarTurno(turnoRaw);
    const { fecha } = req.query;

    // ✅ nuevo: permitir solo consultar sin crear
    const createParam = req.query.create; // "0" | "1" | "true" | "false" | undefined
    const allowCreate =
      createParam === undefined ||
      createParam === null ||
      createParam === "" ||
      createParam === "1" ||
      String(createParam).toLowerCase() === "true";

    if (!turno) return res.status(400).json({ error: "turno es requerido" });
    if (!esTurnoValido(turno))
      return res.status(400).json({ error: "turno no valido" });
    if (!fecha) return res.status(400).json({ error: "fecha es requerida" });

    const fechaValue = fecha
      ? String(fecha)
       : new Date().toLocaleDateString("en-CA");

    // 1) buscar si ya existe un ABIERTO vigente para ese usuario+turno+fecha
    const [rows] = await pool.query(
      `SELECT id, fecha, turno, estado, vence_en, creado_por_nombre
       FROM reportes
       WHERE tipo_reporte = 'APOYO_HORAS'
         AND creado_por_user_id = ?
         AND turno = ?
         AND fecha = ?
         
       ORDER BY id DESC
       LIMIT 1`,
      [userId, turno, fechaValue]
    );

    if (rows.length) {
      return res.json({ existente: true, reporte: rows[0] });
    }

    // ✅ si no existe y NO permites crear -> solo responde "no existe"
    if (!allowCreate) {
      return res.json({ existente: false, reporte: null });
    }

    // 2) si no existe, crear uno nuevo
    const [urows] = await pool.query(
      "SELECT nombre, username FROM users WHERE id = ? AND activo = 1 LIMIT 1",
      [userId]
    );
    if (!urows.length)
      return res.status(401).json({ error: "Usuario invalido o desactivado" });

    const creado_por_nombre = urows[0].nombre || urows[0].username;

     let result;
    try {
      [result] = await pool.query(
        `INSERT INTO reportes
         (fecha, turno, tipo_reporte, area, area_id,
          creado_por_user_id, creado_por_nombre, observaciones,
          estado, vence_en)
         VALUES (?, ?, 'APOYO_HORAS', 'POR_TRABAJADOR', NULL,
                 ?, ?, NULL,
                 'ABIERTO', DATE_ADD(STR_TO_DATE(?, '%Y-%m-%d'), INTERVAL 1 DAY))`,
        [fechaValue, turno, userId, creado_por_nombre, fechaValue]
      );
    } catch (err) {
      if (err && err.code === "ER_DUP_ENTRY") {
        const [duplicado] = await pool.query(
          `SELECT id, fecha, turno, estado, vence_en, creado_por_nombre
           FROM reportes
           WHERE tipo_reporte = 'APOYO_HORAS'
             AND creado_por_user_id = ?
             AND turno = ?
             AND fecha = ?
           ORDER BY id DESC
           LIMIT 1`,
          [userId, turno, fechaValue]
        );

        if (duplicado.length) {
          return res.json({ existente: true, reporte: duplicado[0] });
        }
      }
      throw err;
    }

    const [nuevo] = await pool.query(
      `SELECT id, fecha, turno, estado, vence_en, creado_por_nombre
       FROM reportes
       WHERE id = ?
       LIMIT 1`,
      [result.insertId]
    );

    return res.status(201).json({ existente: false, reporte: nuevo[0] });
  } catch (err) {
    console.error("open apoyo-horas error:", err);
    return res.status(500).json({ error: "Error interno open apoyo-horas" });
  }
});


/* ========================================
   GET /reportes/apoyo-horas/pendientes
======================================== */
router.get("/apoyo-horas/pendientes", authMiddleware, async (req, res) => {
  console.log("[DEBUG pendientes] query", req.query);

  try {
    console.log("[DEBUG pendientes] query", req.query);

    const userId = req.user.id;

    const horasParam = req.query.horas ?? req.query.hours ?? 24;
    const horas = Number(horasParam);
    const horasFiltro = Number.isFinite(horas) && horas > 0 ? horas : 24;

    const fecha = req.query.fecha ? String(req.query.fecha) : null; // "YYYY-MM-DD"
     const turno = req.query.turno ? normalizarTurno(req.query.turno) : null; // "Dia" | "Noche"

    if (turno && !esTurnoValido(turno)) {
      return res.status(400).json({ error: "turno no válido" });
    }

    // ✅ WHERE dinámico
    const where = `
      r.tipo_reporte = 'APOYO_HORAS'
      AND r.creado_por_user_id = ?
      AND r.estado = 'ABIERTO'
      AND (r.vence_en IS NULL OR r.vence_en > NOW())
      AND lr.hora_fin IS NULL
      ${turno ? "AND r.turno = ?" : ""}
      ${
        fecha
          ? "AND DATE(r.fecha) = ?"
          : "AND r.fecha >= (NOW() - INTERVAL ? HOUR)"
      }
    `;

    // ✅ Parámetros en orden según lo que agregues
    const params = [userId];
    if (turno) params.push(turno);

    if (fecha) {
      params.push(fecha);
    } else {
      params.push(horasFiltro);
    }

    const [rows] = await pool.query(
      `SELECT 
          r.id AS report_id,
          r.fecha,
          r.turno,
          r.creado_por_nombre,
          COUNT(*) AS pendiente,
          MAX(lr.area_nombre) AS area_nombre
       FROM reportes r
       JOIN lineas_reporte lr ON lr.reporte_id = r.id
       WHERE ${where}
       GROUP BY r.id
       ORDER BY r.id DESC`,
      params
    );

    return res.json({ items: rows });
  } catch (err) {
    console.error("pendientes apoyo-horas error:", err);
    return res.status(500).json({ error: "Error interno de pendientes" });
  }
});


router.get("/saneamiento/open", authMiddleware, async (req, res) => {
  try {
    const userId = req.user.id;
    const turnoNormalizado = normalizarTurno(req.query.turno);
    const { fecha } = req.query;

    if (!turnoNormalizado) return res.status(400).json({ error: "turno es requerido" });
    if (!esTurnoValido(turnoNormalizado)) {
      return res.status(400).json({ error: "turno no valido" });
    }

      if (fecha && !/^\d{4}-\d{2}-\d{2}$/.test(String(fecha))) {
      return res.status(400).json({ error: "fecha debe tener formato YYYY-MM-DD" });
    }

    const fechaValue = fecha ? String(fecha) : new Date().toISOString().slice(0, 10);
    

    // ✅ 1) Buscar el último reporte del mismo usuario + fecha + turno (cualquier estado)
    const [existentes] = await pool.query(
      `SELECT id, fecha, turno, estado, vence_en, creado_por_nombre
       FROM reportes
       WHERE tipo_reporte = 'SANEAMIENTO'
         AND creado_por_user_id = ?
         AND turno = ?
         AND fecha = ?
       ORDER BY id DESC
       LIMIT 1`,
      [userId, turnoNormalizado, fechaValue]
    );

     // ✅ Si existe, devuelve el existente con bandera allowCreate según estado
    if (existentes.length) {
      const reporte = {
        id: existentes[0].id,
        fecha: existentes[0].fecha,
        turno: existentes[0].turno,
        estado: existentes[0].estado,
      };
      return res.json({
        existente: true,
         modo: existentes[0].estado === "ABIERTO" ? "CONTINUAR" : "VER",
        reporte,
      });
    }

     return res.json({ existente: false });
  } catch (e) {
    console.error("open saneamiento error:", e);
    return res.status(500).json({ error: "Error interno open saneamiento" });
  }
});




/* ========================================
   GET /reportes/saneamiento/pendientes
======================================== */
router.get("/saneamiento/pendientes", authMiddleware, async (req, res) => {
  try {
    const userId = req.user.id;
    const horasParam = req.query.horas ?? req.query.hours ?? 24;
    const horas = Number(horasParam);
    const horasFiltro = Number.isFinite(horas) && horas > 0 ? horas : 24;

    const [rows] = await pool.query(
      `SELECT 
          r.id AS report_id,
          r.fecha,
          r.turno,
          r.creado_por_nombre,
          r.estado,
          r.vence_en,
          COUNT(*) AS pendiente
       FROM reportes r
       JOIN lineas_reporte lr ON lr.reporte_id = r.id
       WHERE r.tipo_reporte = 'SANEAMIENTO'
         AND r.creado_por_user_id = ?
         AND r.estado = 'ABIERTO'
         AND (r.vence_en IS NULL OR r.vence_en > NOW())
         AND r.creado_en >= (NOW() - INTERVAL ? HOUR)
         AND (
           lr.hora_fin IS NULL
           OR lr.labores IS NULL
           OR TRIM(lr.labores) = ''
         )
       GROUP BY r.id
       ORDER BY r.id DESC`,
      [userId, horasFiltro]
    );

    return res.json({ items: rows });
  } catch (e) {
    console.error("pendientes saneamiento error:", e);
    return res.status(500).json({ error: "Error interno de pendientes" });
  }
});

// ========================================
// GET /reportes/conteo-rapido/open
// ========================================
router.get("/conteo-rapido/open", authMiddleware, async (req, res) => {
  try {
    const userId = req.user.id;
    const turno = normalizarTurno(req.query.turno);
    const fechaValue = req.query.fecha
      ? String(req.query.fecha)
      : new Date().toISOString().slice(0, 10);

    if (!turno) return res.status(400).json({ error: "turno es requerido" });
    if (!esTurnoValido(turno)) return res.status(400).json({ error: "turno no válido" });

    // ⚠️ tu BD usa enum('Dia','Noche'), asegúrate que normalizarTurno devuelve "Dia" o "Noche"
    // (sin tilde)

    // 1) buscar reporte existente
    const [repRows] = await pool.query(
      `SELECT id, fecha, turno, estado, creado_por_nombre
       FROM reportes
       WHERE tipo_reporte = 'CONTEO_RAPIDO'
         AND creado_por_user_id = ?
         AND fecha = ?
         AND turno = ?
       ORDER BY id DESC
       LIMIT 1`,
      [userId, fechaValue, turno]
    );

    // si existe -> devolver con items
    if (repRows.length) {
      const reporte = repRows[0];
      const [items] = await pool.query(
        `SELECT d.area_id, a.nombre AS area_nombre, d.cantidad
         FROM conteo_rapido_detalle d
         JOIN areas a ON a.id = d.area_id
         LEFT JOIN conteo_rapido_area_orden o ON o.area_id = a.id
         WHERE d.reporte_id = ?
         ORDER BY COALESCE(o.orden, 9999), a.nombre`,
        [reporte.id]
      );
      return res.json({ existente: true, reporte, items });
    }

    // 2) si NO existe, crear cabecera VACÍA
    const [urows] = await pool.query(
      "SELECT nombre, username FROM users WHERE id = ? AND activo = 1 LIMIT 1",
      [userId]
    );
    if (!urows.length) return res.status(401).json({ error: "Usuario inválido o desactivado" });

    const creado_por_nombre = urows[0].nombre || urows[0].username;

    // tu columna reportes.area es NOT NULL -> pon algo fijo
    const [ins] = await pool.query(
      `INSERT INTO reportes
       (fecha, turno, tipo_reporte, area, area_id,
        creado_por_user_id, creado_por_nombre, observaciones,
        estado, vence_en)
       VALUES (?, ?, 'CONTEO_RAPIDO', ?, NULL,
               ?, ?, NULL,
               'ABIERTO', NULL)`,
      [fechaValue, turno, "POR_AREAS", userId, creado_por_nombre]
    );

    const reporteId = ins.insertId;

    const [nuevo] = await pool.query(
      `SELECT id, fecha, turno, estado, creado_por_nombre
       FROM reportes
       WHERE id = ?
       LIMIT 1`,
      [reporteId]
    );

    return res.status(201).json({ existente: false, reporte: nuevo[0], items: [] });
  } catch (e) {
    console.error("open conteo-rapido error:", e);
    return res.status(500).json({ error: "Error interno open conteo-rapido" });
  }
});

/* ========================================
   GET /reportes/trabajo-avance/open
======================================== */
router.get("/trabajo-avance/open", authMiddleware, async (req, res) => {
  try {
    const userId = req.user.id;
    const turno = normalizarTurno(req.query.turno);
    const fechaValue = req.query.fecha ? String(req.query.fecha) : null;

    if (!fechaValue) return res.status(400).json({ error: "fecha es requerida" });
    if (!turno) return res.status(400).json({ error: "turno es requerido" });
    if (!esTurnoValido(turno)) return res.status(400).json({ error: "turno no valido" });

    const [rows] = await pool.query(
      `SELECT id, fecha, turno, estado, creado_por_nombre
       FROM reportes
       WHERE tipo_reporte='TRABAJO_AVANCE'
         AND creado_por_user_id=?
         AND fecha=?
         AND turno=?
       ORDER BY id DESC
       LIMIT 1`,
      [userId, fechaValue, turno]
    );

    if (!rows.length) return res.json({ existente: false });

    return res.json({ existente: true, reporte: rows[0] });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: "Error interno open trabajo-avance" });
  }
});

router.post("/trabajo-avance/start", authMiddleware, async (req, res) => {
  try {
    const userId = req.user.id;
    const turno = normalizarTurno(req.body.turno);
    const fechaValue = req.body.fecha ? String(req.body.fecha) : null;

    if (!fechaValue) return res.status(400).json({ error: "fecha es requerida" });
    if (!turno) return res.status(400).json({ error: "turno es requerido" });
    if (!esTurnoValido(turno)) return res.status(400).json({ error: "turno no valido" });

    // 1) si existe, devuélvelo (sin crear duplicado)
    const [rows] = await pool.query(
      `SELECT id, fecha, turno, estado, creado_por_nombre
       FROM reportes
       WHERE tipo_reporte = 'TRABAJO_AVANCE'
         AND creado_por_user_id = ?
         AND turno = ?
         AND fecha = ?
       ORDER BY id DESC
       LIMIT 1`,
      [userId, turno, fechaValue]
    );

    if (rows.length) {
      return res.json({ existente: true, reporte: rows[0] });
    }

    // 2) crear ABIERTO
    const [urows] = await pool.query(
      "SELECT nombre, username FROM users WHERE id = ? AND activo = 1 LIMIT 1",
      [userId]
    );
    if (!urows.length) return res.status(401).json({ error: "Usuario invalido o desactivado" });

    const creado_por_nombre = urows[0].nombre || urows[0].username;

    const [ins] = await pool.query(
      `INSERT INTO reportes
       (fecha, turno, tipo_reporte, area, area_id,
        creado_por_user_id, creado_por_nombre, observaciones,
        estado, vence_en)
       VALUES (?, ?, 'TRABAJO_AVANCE', ?, NULL,
               ?, ?, NULL,
               'ABIERTO', NULL)`,
      [fechaValue, turno, "POR_CUADRILLA", userId, creado_por_nombre]
    );

    const [nuevo] = await pool.query(
      `SELECT id, fecha, turno, estado, creado_por_nombre
       FROM reportes
       WHERE id = ?
       LIMIT 1`,
      [ins.insertId]
    );

    return res.status(201).json({ existente: false, reporte: nuevo[0] });
  } catch (e) {
    console.error("start trabajo-avance error:", e);
    return res.status(500).json({ error: "Error interno start trabajo-avance" });
  }
});





/* ========================================
   GET /reportes/trabajo-avance/:id/resumen
   (Lista cuadrillas por sección + totales)
======================================== */
router.get("/trabajo-avance/:id/resumen", authMiddleware, async (req, res) => {
  try {
    const reporteId = Number(req.params.id);
    if (!Number.isInteger(reporteId) || reporteId <= 0) {
      return res.status(400).json({ error: "id inválido" });
    }

    const [cuadrillas] = await pool.query(
      `SELECT id, reporte_id, tipo, nombre, hora_inicio, hora_fin, produccion_kg, apoyo_scope, apoyo_de_cuadrilla_id
       FROM trabajo_avance_cuadrillas
       WHERE reporte_id = ?
       ORDER BY FIELD(tipo,'RECEPCION','FILETEADO','APOYO_RECEPCION'), nombre`,
      [reporteId]
    );

    const recepcion = cuadrillas
      .filter((c) => c.tipo === "RECEPCION")
      .map((c) => ({
        ...c,
        produccion_kg: 0,
         kg: Number(c.produccion_kg || 0),
      }));

    const fileteado = cuadrillas
      .filter((c) => c.tipo === "FILETEADO")
      .map((c) => ({
        ...c,
        kg: Number(c.produccion_kg || 0),
      }));

    const apoyos = cuadrillas
      .filter((c) => c.tipo === "APOYO_RECEPCION")
      .map((c) => ({
        ...c,
        produccion_kg: 0,
        kg: 0,
      }));

    const totalKgRecepcion = recepcion.reduce(
      (acc, c) => acc + Number(c.kg || 0),
      0
    );
    const totalKgFileteado = fileteado.reduce(
      (acc, c) => acc + Number(c.kg || 0),
      0
    );

    const apoyosGlobal = apoyos.filter((c) => !c.apoyo_de_cuadrilla_id);
    const apoyosPorCuadrillaMap = new Map();
    for (const apoyo of apoyos) {
      if (!apoyo.apoyo_de_cuadrilla_id) continue;
      if (!apoyosPorCuadrillaMap.has(apoyo.apoyo_de_cuadrilla_id)) {
        const cuadrillaFileteado =
          fileteado.find((c) => c.id === apoyo.apoyo_de_cuadrilla_id) || {
            id: apoyo.apoyo_de_cuadrilla_id,
          };
        apoyosPorCuadrillaMap.set(apoyo.apoyo_de_cuadrilla_id, {
          cuadrillaFileteado,
          apoyos: [],
        });
      }
      apoyosPorCuadrillaMap.get(apoyo.apoyo_de_cuadrilla_id).apoyos.push(apoyo);
    }

    const apoyos_recepcion = {
      global: apoyosGlobal,
      por_cuadrilla: Array.from(apoyosPorCuadrillaMap.values()),
    };

    const totales = { RECEPCION: 0, FILETEADO: totalKgFileteado, APOYO_RECEPCION: 0 };


    return res.json({
      reporteId,
      recepcion,
      fileteado: { lista: fileteado, totalKg: totalKgFileteado },
      apoyos_recepcion,
      totales: {
        ...totales,
        RECEPCION: totalKgRecepcion,
        FILETEADO: totalKgFileteado,
      },
      cuadrillas,
    });
  } catch (e) {
    console.error("resumen trabajo-avance error:", e);
    return res.status(500).json({ error: "Error interno resumen trabajo-avance" });
  }
});

/* ========================================
   POST /reportes/trabajo-avance/:id/cuadrillas
   body: { tipo, nombre, apoyoDeCuadrillaId? }
======================================== */
router.post("/trabajo-avance/:id/cuadrillas", authMiddleware, async (req, res) => {
  try {
    const reporteId = Number(req.params.id);
    const {
      tipo,
      nombre,
      apoyoDeCuadrillaId,
      apoyo_scope,
      apoyo_de_cuadrilla_id,
    } = req.body || {};

    if (!Number.isInteger(reporteId) || reporteId <= 0) return res.status(400).json({ error: "id inválido" });
    if (!tipoTrabajoAvanceValido(tipo)) return res.status(400).json({ error: "tipo inválido" });
    if (!nombre || !String(nombre).trim()) return res.status(400).json({ error: "nombre requerido" });

    let apoyoScopeFinal = null;
    let apoyoCuadrillaFinal = null;

    if (tipo === "APOYO_RECEPCION") {
      apoyoScopeFinal = String(apoyo_scope ?? "GLOBAL").trim().toUpperCase();
      if (!["GLOBAL", "CUADRILLA"].includes(apoyoScopeFinal)) {
        return res.status(400).json({ error: "apoyo_scope inválido" });
      }

      if (apoyoScopeFinal === "CUADRILLA") {
        const apoyoCuadrillaId = Number(
          apoyo_de_cuadrilla_id ?? apoyoDeCuadrillaId
        );
        if (!Number.isInteger(apoyoCuadrillaId) || apoyoCuadrillaId <= 0) {
          return res.status(400).json({ error: "apoyo_de_cuadrilla_id requerido" });
        }

        const [[cuadrillaApoyo]] = await pool.query(
          `SELECT id
           FROM trabajo_avance_cuadrillas
           WHERE id = ?
             AND reporte_id = ?
             AND tipo = 'FILETEADO'
           LIMIT 1`,
          [apoyoCuadrillaId, reporteId]
        );

        if (!cuadrillaApoyo) {
          return res.status(400).json({ error: "apoyo_de_cuadrilla_id inválido" });
        }

        apoyoCuadrillaFinal = apoyoCuadrillaId;
      }
    }

    const [ins] = await pool.query(
     `INSERT INTO trabajo_avance_cuadrillas (
        reporte_id,
        tipo,
        nombre,
        apoyo_scope,
        apoyo_de_cuadrilla_id
       )
       VALUES (?, ?, ?, ?, ?)`,
      [
        reporteId,
        tipo,
        String(nombre).trim(),
        apoyoScopeFinal,
        apoyoCuadrillaFinal,
      ]
    );

    const [[row]] = await pool.query(
      `SELECT id, reporte_id, tipo, nombre, hora_inicio, hora_fin, produccion_kg, apoyo_scope, apoyo_de_cuadrilla_id
       FROM trabajo_avance_cuadrillas WHERE id = ?`,
      [ins.insertId]
    );

    return res.status(201).json({ ok: true, cuadrilla: row });
  } catch (e) {
    console.error("crear cuadrilla trabajo-avance error:", e);
    return res.status(500).json({ error: "Error interno creando cuadrilla" });
  }
});

/* ========================================
   GET /reportes/trabajo-avance/cuadrillas/:cuadrillaId
======================================== */
router.get(
  "/trabajo-avance/cuadrillas/:cuadrillaId",
  authMiddleware,
  async (req, res) => {
    

    try {
      
      const cuadrillaId = Number(req.params.cuadrillaId);
      if (!Number.isInteger(cuadrillaId) || cuadrillaId <= 0) {
        return res.status(400).json({ error: "cuadrillaId inválido" });
      }

      const [[cuadrilla]] = await pool.query(
        `SELECT id, reporte_id, tipo, nombre, hora_inicio, hora_fin, produccion_kg, apoyo_scope, apoyo_de_cuadrilla_id
         FROM trabajo_avance_cuadrillas
         WHERE id = ?`,
        [cuadrillaId]
      );

      if (!cuadrilla) {
        return res.status(404).json({ error: "Cuadrilla no encontrada" });
      }

      // ✅ Traer nombre desde tabla "trabajadores" (JOIN) usando TRIM por los espacios
      const [trabajadoresRaw] = await pool.query(
        `SELECT
           tav.id,
           tav.cuadrilla_id,
           TRIM(tav.trabajador_codigo) AS trabajador_codigo,
           tav.trabajador_nombre,
           tav.kg
         FROM trabajo_avance_trabajadores tav
        
         WHERE tav.cuadrilla_id = ?
         ORDER BY tav.id DESC`,
        [cuadrillaId]
      );

       const payload = {
        cuadrilla,
        trabajadores: Array.isArray(trabajadoresRaw) ? trabajadoresRaw : [],
      };

      // ✅ log correcto: ya existe payload
      console.log("RESP CUADRILLA:", JSON.stringify(payload, null, 2));

      return res.json({
        cuadrilla,
        trabajadores: Array.isArray(trabajadoresRaw) ? trabajadoresRaw : [],
      });

    } catch (e) {
       if (e?.code === "TRABAJADOR_NO_ENCONTRADO") {
        return res.status(404).json({ error: "TRABAJADOR_NO_ENCONTRADO" });
      }
      console.error("detalle cuadrilla trabajo-avance error:", e);
      return res
        .status(500)
        .json({ error: "Error interno detalle cuadrilla" });
    }
  }
);

router.put("/trabajo-avance/:reporteId", authMiddleware, async (req, res) => {
  try {
    const userId = req.user.id;
    const reporteId = Number(req.params.reporteId);
    const { estado } = req.body || {};

    if (!Number.isInteger(reporteId) || reporteId <= 0) {
      return res.status(400).json({ error: "reporteId inválido" });
    }

    const estadoFinal = (estado ?? "CERRADO").toString();

    // validar que sea del usuario y del tipo correcto
    const [[rep]] = await pool.query(
      `SELECT id
       FROM reportes
       WHERE id = ?
         AND tipo_reporte = 'TRABAJO_AVANCE'
         AND creado_por_user_id = ?
       LIMIT 1`,
      [reporteId, userId]
    );

    if (!rep) return res.status(404).json({ error: "Reporte no encontrado" });

    await pool.query(
      `UPDATE reportes
       SET estado = ?
       WHERE id = ?`,
      [estadoFinal, reporteId]
    );

    const [[row]] = await pool.query(
      `SELECT id, fecha, turno, estado, creado_por_nombre
       FROM reportes
       WHERE id = ?
       LIMIT 1`,
      [reporteId]
    );

    return res.json({ ok: true, reporte: row });
  } catch (e) {
    console.error("put trabajo-avance reporte error:", e);
    return res.status(500).json({ error: "Error interno actualizando reporte" });
  }
});









/* ========================================
   PUT /trabajo-avance/cuadrillas/:cuadrillaId
   body: { hora_inicio, hora_fin, produccion_kg }
======================================== */
router.put("/trabajo-avance/cuadrillas/:cuadrillaId", authMiddleware, async (req, res) => {
  try {
    const cuadrillaId = Number(req.params.cuadrillaId);
    const { hora_inicio, hora_fin, produccion_kg } = req.body || {};

     console.log(
      "TA update cuadrilla req.body:",
      JSON.stringify(req.body ?? {}, null, 2)
    );


    if (!Number.isInteger(cuadrillaId) || cuadrillaId <= 0) {
      return res.status(400).json({ error: "cuadrillaId inválido" });
    }

    const [[cuadrillaActual]] = await pool.query(
      `SELECT tipo
       FROM trabajo_avance_cuadrillas
       WHERE id = ?
       LIMIT 1`,
      [cuadrillaId]
    );

    if (!cuadrillaActual) {
      return res.status(404).json({ error: "Cuadrilla no encontrada" });
    }

    const produccionKgNormalized =
      produccion_kg == null
        ? 0
        : Number(String(produccion_kg).replace(/,/g, "."));

    if (!Number.isFinite(produccionKgNormalized)) {
      return res.status(400).json({
        error: "produccion_kg inválido",
        value: produccion_kg,
      });
    }

    console.log(
      `TA update cuadrilla parsed -> cuadrillaId=${cuadrillaId}, produccion_kg=${produccionKgNormalized}`
    );

    const [updateResult] = await pool.query(
      `UPDATE trabajo_avance_cuadrillas
       SET hora_inicio = ?, hora_fin = ?, produccion_kg = ?
       WHERE id = ?`,
      [hora_inicio ?? null, hora_fin ?? null, produccionKgNormalized, cuadrillaId]
    );

    if (!updateResult?.affectedRows) {
      return res.status(409).json({
        error: "No se actualizó la cuadrilla",
        cuadrillaId,
      });
    }

    


    const [[row]] = await pool.query(
       `SELECT id, reporte_id, tipo, nombre, hora_inicio, hora_fin, produccion_kg, apoyo_scope, apoyo_de_cuadrilla_id
       FROM trabajo_avance_cuadrillas WHERE id = ?`,
      [cuadrillaId]
    );

    if (!row) {
      return res.status(500).json({
        error: "No se pudo leer la cuadrilla actualizada",
        cuadrillaId,
      });
    }

    const [[postUpdateRow]] = await pool.query(
      `SELECT id, produccion_kg
       FROM trabajo_avance_cuadrillas
       WHERE id = ?
       LIMIT 1`,
      [cuadrillaId]
    );

    console.log(
      "TA update cuadrilla post-update:",
      JSON.stringify(postUpdateRow ?? {}, null, 2)
    );

    return res.json({ ok: true, cuadrilla: row });
  } catch (e) {
    console.error("update cuadrilla trabajo-avance error:", e);
    return res.status(500).json({ error: "Error interno actualizando cuadrilla" });
  }
});

/* ========================================
   POST /reportes/trabajo-avance/cuadrillas/:cuadrillaId/trabajadores
   body: { codigo, nombre? }
======================================== */
router.post("/trabajo-avance/cuadrillas/:cuadrillaId/trabajadores", authMiddleware, async (req, res) => {
  try {
    const cuadrillaId = Number(req.params.cuadrillaId);
    const { q, codigo } = req.body || {};

    if (!Number.isInteger(cuadrillaId) || cuadrillaId <= 0) {
      return res.status(400).json({ error: "cuadrillaId inválido" });
    }
    const lookupInput = q ?? codigo;
    const { worker: trabajador } = await resolveTrabajadorLookup({
      q: lookupInput,
      pool,
    });

    await pool.query(
      `INSERT INTO trabajo_avance_trabajadores (cuadrilla_id, trabajador_codigo, trabajador_nombre)
       VALUES (?, ?, ?)`,
        [cuadrillaId, String(trabajador.codigo ?? "").trim(), trabajador.nombre ?? null]
    );

    const [trabajadoresRaw] = await pool.query(
      `SELECT id, cuadrilla_id, trabajador_codigo, trabajador_nombre, kg
       FROM trabajo_avance_trabajadores
       WHERE cuadrilla_id = ?
       ORDER BY id DESC`,
      [cuadrillaId]
    );

    const trabajadores = await hidratarTrabajadoresPorCodigo(trabajadoresRaw);

    return res.status(201).json({ ok: true, trabajadores });
  } catch (e) {
     if (String(e?.code) === "Q_REQUERIDO") {
      return res.status(400).json({ error: "q es requerido" });
    }
    if (String(e?.code) === "CODIGO_INVALIDO") {
      return res.status(400).json({ error: "CODIGO_INVALIDO" });
    }
    if (String(e?.code) === "TRABAJADOR_NO_ENCONTRADO") {
      return res.status(404).json({ error: "TRABAJADOR_NO_ENCONTRADO", q: e?.q, tipoDetectado: e?.tipoDetectado });
    }
    if (String(e?.code) === "ER_DUP_ENTRY") {
      return res.status(409).json({ error: "El trabajador ya está en esta cuadrilla" });
    }
    console.error("add trabajador trabajo-avance error:", e);
    return res.status(500).json({ error: "Error interno agregando trabajador" });
  }
});

/* ========================================
   DELETE /reportes/trabajo-avance/trabajadores/:id
======================================== */
router.delete("/trabajo-avance/trabajadores/:id", authMiddleware, async (req, res) => {
  try {
    const id = Number(req.params.id);
    if (!Number.isInteger(id) || id <= 0) return res.status(400).json({ error: "id inválido" });

    await pool.query(`DELETE FROM trabajo_avance_trabajadores WHERE id = ?`, [id]);
    return res.json({ ok: true });
  } catch (e) {
    console.error("delete trabajador trabajo-avance error:", e);
    return res.status(500).json({ error: "Error interno eliminando trabajador" });
  }
});



// ===============================================
// POST /reportes/conteo-rapido  (GUARDAR)
// Body: { fecha: 'YYYY-MM-DD', turno: 'Dia'|'Noche', items: [{area_id, cantidad}] }
// ===============================================
router.post("/conteo-rapido", authMiddleware, async (req, res) => {
  const userId = req.user.id;

  const { fecha, turno, items } = req.body;

  if (!fecha) return res.status(400).json({ error: "fecha es requerida" });
  if (!turno) return res.status(400).json({ error: "turno es requerido" });
  if (!Array.isArray(items) || items.length === 0) {
    return res.status(400).json({ error: "items es requerido (lista de áreas)" });
  }

  // Normaliza turno como ya lo haces
  const turnoNormalizado = normalizarTurno(turno);
  if (!esTurnoValido(turnoNormalizado)) {
    return res.status(400).json({ error: "turno no válido" });
  }

  // Validación items
  for (const it of items) {
    const areaId = Number(it.area_id);
    const cantidad = Number(it.cantidad);
    if (!Number.isInteger(areaId) || areaId <= 0) {
      return res.status(400).json({ error: "area_id inválido en items" });
    }
    if (!Number.isFinite(cantidad) || cantidad < 0) {
      return res.status(400).json({ error: "cantidad inválida en items" });
    }
  }

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

    // nombre del usuario (planillero) desde BD
    const [urows] = await conn.query(
      "SELECT nombre, username FROM users WHERE id = ? AND activo = 1 LIMIT 1",
      [userId]
    );
    if (!urows.length) {
      await conn.rollback();
      return res.status(401).json({ error: "Usuario inválido o desactivado" });
    }
    const creado_por_nombre = urows[0].nombre || urows[0].username;

    // 1) buscar si ya existe reporte CONTEO_RAPIDO del user/fecha/turno
    const [exist] = await conn.query(
      `SELECT id
       FROM reportes
       WHERE tipo_reporte = 'CONTEO_RAPIDO'
         AND creado_por_user_id = ?
         AND fecha = ?
         AND turno = ?
       ORDER BY id DESC
       LIMIT 1`,
      [userId, fecha, turnoNormalizado]
    );

    let reporteId;
    if (exist.length) {
      reporteId = exist[0].id;
    } else {
      // 2) crear cabecera reporte
      const [ins] = await conn.query(
  `INSERT INTO reportes
   (fecha, turno, tipo_reporte, area, area_id,
    creado_por_user_id, creado_por_nombre, observaciones,
    estado, vence_en)
   VALUES (?, ?, 'CONTEO_RAPIDO', ?, NULL,
           ?, ?, NULL,
           'ABIERTO', NULL)`,
  [fecha, turnoNormalizado, "POR_AREAS", userId, creado_por_nombre]
);

      reporteId = ins.insertId;
    }

    // 3) guardar detalle en conteo_rapido_detalle (upsert)
    // Requiere UNIQUE(reporte_id, area_id)
    for (const it of items) {
      const areaId = Number(it.area_id);
      const cantidad = Number(it.cantidad);

      await conn.query(
        `INSERT INTO conteo_rapido_detalle (reporte_id, area_id, cantidad)
         VALUES (?, ?, ?)
         ON DUPLICATE KEY UPDATE cantidad = VALUES(cantidad)`,
        [reporteId, areaId, cantidad]
      );
    }

    // (Opcional) cerrar al guardar
    await conn.query(
      `UPDATE reportes
       SET estado = 'CERRADO', cerrado_en = NOW()
       WHERE id = ?`,
      [reporteId]
    );

    await conn.commit();
    return res.status(201).json({ ok: true, reporte_id: reporteId });
  } catch (e) {
    await conn.rollback();
    console.error("POST /reportes/conteo-rapido error:", e);
    return res.status(500).json({ error: "Error guardando conteo rápido", details: String(e) });
  } finally {
    conn.release();
  }
});



/* =========================================
   PATCH /reportes/lineas/:lineaId
========================================= */
router.patch("/lineas/:lineaId", authMiddleware, async (req, res) => {
  try {
    const lineaId = Number(req.params.lineaId);
    if (!Number.isInteger(lineaId) || lineaId <= 0) {
      return res.status(400).json({ error: "lineaId inválido" });
    }

    const body = req.body || {};
    const clear = req.query.clear === "true" || req.body?.clear === true;

    const hasField = (field) =>
      Object.prototype.hasOwnProperty.call(body, field);

   

    const [lineaRows] = await pool.query(
      `SELECT lineas_reporte.reporte_id,
              lineas_reporte.hora_inicio,
              reportes.tipo_reporte
       FROM lineas_reporte
       INNER JOIN reportes ON reportes.id = lineas_reporte.reporte_id
       WHERE lineas_reporte.id = ?
       LIMIT 1`,
      [lineaId]
    );
    if (!lineaRows.length) {
      return res.status(404).json({ error: "Linea no encontrada" });
    }

    const existingLinea = lineaRows[0];
    const reporteId = existingLinea.reporte_id;
     const tipoReporte = existingLinea.tipo_reporte;

    const updates = [];
    const params = [];

     if (hasField("trabajador_id")) {
      const value = body.trabajador_id;
      if (value === null) {
        if (clear) {
          updates.push("trabajador_id = ?");
          params.push(null);
        }
      } else {
        updates.push("trabajador_id = ?");
        params.push(value);
      }
    }
    if (hasField("trabajador_codigo")) {
      const value = body.trabajador_codigo;
      if (value === null) {
        if (clear) {
          updates.push("trabajador_codigo = ?");
          params.push(null);
        }
      } else {
        updates.push("trabajador_codigo = ?");
        params.push(String(value).trim());
      }
    }
    if (hasField("trabajador_nombre")) {
      const value = body.trabajador_nombre;
      if (value === null) {
        if (clear) {
          updates.push("trabajador_nombre = ?");
          params.push(null);
        }
      } else {
        updates.push("trabajador_nombre = ?");
        params.push(String(value).trim());
      }
    }
    if (hasField("trabajador_documento")) {
      const value = body.trabajador_documento;
      if (value === null) {
        if (clear) {
          updates.push("trabajador_documento = ?");
          params.push(null);
        }
      } else {
        updates.push("trabajador_documento = ?");
        params.push(String(value).trim());
      }
    }

    if (hasField("cuadrilla_id")) {
      const value = body.cuadrilla_id;
      if (value === null) {
        if (clear) {
          updates.push("cuadrilla_id = ?");
          params.push(null);
        }
      } else {
        updates.push("cuadrilla_id = ?");
        params.push(value);
      }
    }
    if (hasField("hora_inicio")) {
      const value = body.hora_inicio;
      if (value === null) {
        if (clear) {
          updates.push("hora_inicio = ?");
          params.push(null);
        }
      } else {
        updates.push("hora_inicio = ?");
         params.push(value);
      }
      
    }

    if (hasField("hora_fin")) {
      const value = body.hora_fin;
      if (value === null) {
        if (clear) {
          updates.push("hora_fin = ?");
          params.push(null);
        }
      } else {
        updates.push("hora_fin = ?");
        params.push(value);
      }
    }
    if (hasField("kilos")) {
      const value = body.kilos;
      if (value === null) {
        if (clear) {
          updates.push("kilos = ?");
          params.push(null);
        }
      } else {
        updates.push("kilos = ?");
        params.push(value);
      }
    }
    if (hasField("labores")) {
      const value = body.labores;
      if (value === null) {
        if (clear) {
          updates.push("labores = ?");
          params.push(null);
        }
      } else {
        updates.push("labores = ?");
        params.push(value);
      }
    }

    // area (opcional)
    if (hasField("area_id")) {
      const value = body.area_id;
      if (value === null) {
        if (clear) {
          updates.push("area_id = ?");
          params.push(null);
          updates.push("area_nombre = ?");
          params.push(null);
        }
      } else {
        updates.push("area_id = ?");
        params.push(value);

       const [aRows] = await pool.query(
          "SELECT nombre FROM areas WHERE id = ? LIMIT 1",
          [value]
        );
        const areaNombre = aRows[0]?.nombre ?? null;
        updates.push("area_nombre = ?");
        params.push(areaNombre);
      }
    }

    // recalcular horas si llega hora_fin y no mandan horas
    const horaFinLlego = hasField("hora_fin");
    const horaFinValue = horaFinLlego ? body.hora_fin : undefined;
    const horaFinReal = horaFinLlego && horaFinValue !== null;
    const permiteCalculoHoras = horaFinReal || clear;
    const horaInicioParaCalculo =
      hasField("hora_inicio")
        ? body.hora_inicio ?? null
        : existingLinea.hora_inicio;

    let horasCalculadas;
      if (permiteCalculoHoras && horaFinValue && horaInicioParaCalculo) {
        try {
          horasCalculadas = calcularTotalHoras(horaInicioParaCalculo, horaFinValue);
        } catch (error) {
          return res.status(400).json({ error: error.message });
        }
      }


   if (hasField("horas")) {
      const value = body.horas;
      if (value === null) {
        if (clear) {
          updates.push("horas = ?");
          params.push(null);
        }
      } else {
        updates.push("horas = ?");
        params.push(value);
      }
    } else if (horaFinReal && horasCalculadas !== undefined) {
      updates.push("horas = ?");
      params.push(horasCalculadas);
    }

    if (!updates.length) {
      return res.status(400).json({ error: "No hay campos para actualizar" });

    
    }

    const sql = `UPDATE lineas_reporte SET ${updates.join(", ")} WHERE id = ?`;
    const paramsFinal = [...params, lineaId];

    console.log("TEMP LOG (remover luego) PATCH /reportes/lineas/:lineaId payload final", {
      lineaId,
      clear,
      sql,
      params: paramsFinal,
    });




    console.log("[debug][PATCH /reportes/lineas/:lineaId] SQL", {
       sql,
      params: paramsFinal,
    });

     if (hasField("hora_inicio") && body.hora_inicio === null) {
      console.warn("[debug][PATCH /reportes/lineas/:lineaId] SQL", {
        sql,
        params: paramsFinal,
      });
    }

   

    const [result] = await pool.query(sql, paramsFinal);
    if (result.affectedRows === 0) {
      return res.status(404).json({ error: "Linea no encontrada" });
    }

    // ✅ Recalcular estado del reporte (aplica a APOYO_HORAS y SANEAMIENTO)
    const info = await recalcularEstadoReporte(reporteId);

    return res.json({
      message: "Linea actualizada",
      pendientes: info.pendientes,
      estado_reporte: info.estado,
    });
  } catch (err) {
    console.error("Error actualizando linea:", err);
    return res.status(500).json({ error: "Error interno al actualizar linea" });
  }
});

/* =========================================
   DELETE /reportes/lineas/:lineaId
========================================= */
router.delete("/lineas/:lineaId", authMiddleware, async (req, res) => {
  try {
    const lineaId = Number(req.params.lineaId);
    if (!Number.isInteger(lineaId) || lineaId <= 0) {
      return res.status(400).json({ error: "lineaId inválido" });
    }

    // para recalcular estado, necesitamos reporte_id antes de borrar
    const [lineaRows] = await pool.query(
      "SELECT reporte_id FROM lineas_reporte WHERE id = ? LIMIT 1",
      [lineaId]
    );
    if (!lineaRows.length) return res.status(404).json({ error: "Linea no encontrada" });

    const reporteId = lineaRows[0].reporte_id;

    const [result] = await pool.query("DELETE FROM lineas_reporte WHERE id = ?", [
      lineaId,
    ]);

    if (result.affectedRows === 0) {
      return res.status(404).json({ error: "Linea no encontrada" });
    }

    const info = await recalcularEstadoReporte(reporteId);

    return res.json({
      message: "Linea eliminada",
      pendientes: info.pendientes,
      estado_reporte: info.estado,
    });
  } catch (err) {
    console.error("Error eliminando linea:", err);
    return res.status(500).json({ error: "Error interno al eliminar linea" });
  }
});

/* =======================================
   GET /reportes/:id/lineas
======================================= */
router.get("/:id/lineas", authMiddleware, async (req, res) => {
  try {
    const reporteId = Number(req.params.id);
    if (!Number.isInteger(reporteId) || reporteId <= 0) {
      return res.status(400).json({ error: "id de reporte inválido" });
    }

    const [rows] = await pool.query(
      `SELECT
         lr.id,
         lr.reporte_id,
         lr.trabajador_id,
         lr.cuadrilla_id,

        CASE
           WHEN TRIM(COALESCE(NULLIF(lr.trabajador_codigo, ''), t.codigo, CAST(lr.trabajador_id AS CHAR))) REGEXP '^[0-9]+$'
             THEN LPAD(TRIM(COALESCE(NULLIF(lr.trabajador_codigo, ''), t.codigo, CAST(lr.trabajador_id AS CHAR))), 5, '0')
           ELSE TRIM(COALESCE(NULLIF(lr.trabajador_codigo, ''), t.codigo, CAST(lr.trabajador_id AS CHAR)))
         END AS trabajador_codigo,
         COALESCE(NULLIF(lr.trabajador_nombre, ''), t.nombre_completo, '') AS trabajador_nombre,
         COALESCE(NULLIF(lr.trabajador_documento, ''), t.dni) AS trabajador_documento,
         lr.trabajador_nombre AS trabajador_nombre_origen,

         lr.area_id,
         lr.area_nombre,

         lr.hora_inicio,
         lr.hora_fin,
         lr.horas,

         lr.kilos,
         lr.labores,

         c.nombre AS cuadrilla_nombre,
         t.nombre_completo AS trabajador_nombre_join
       FROM lineas_reporte lr
       LEFT JOIN cuadrillas c ON c.id = lr.cuadrilla_id
       LEFT JOIN trabajadores t
         ON (
           TRIM(t.codigo) REGEXP '^[0-9]+$'
           AND TRIM(COALESCE(NULLIF(lr.trabajador_codigo, ''), CAST(lr.trabajador_id AS CHAR))) REGEXP '^[0-9]+$'
           AND CAST(TRIM(t.codigo) AS UNSIGNED) = CAST(TRIM(COALESCE(NULLIF(lr.trabajador_codigo, ''), CAST(lr.trabajador_id AS CHAR))) AS UNSIGNED)
         )
         OR TRIM(t.codigo) = TRIM(COALESCE(NULLIF(lr.trabajador_codigo, ''), CAST(lr.trabajador_id AS CHAR)))
       WHERE lr.reporte_id = ?
       ORDER BY lr.id ASC`,
      [reporteId]
    );

      const joinFillCount = rows.filter(
      (item) => !String(item?.trabajador_nombre_origen ?? '').trim() && String(item?.trabajador_nombre_join ?? '').trim()
    ).length;

    const items = rows.map(({ trabajador_nombre_join, trabajador_nombre_origen, ...rest }) => rest);

    console.log("TEMP LOG (remover luego) GET /reportes/:id/lineas", {
      reporteId,
       itemsCount: items.length,
      nombreDesdeJoinCount: joinFillCount,
    });

   

     return res.json({ items });
  } catch (err) {
    
    console.error("Error listando lineas:", err);
    return res.status(500).json({ error: "Error interno al listar lineas" });
  }
});



// ===================================================
// GET /reportes/conteo-rapido/:id/excel

// ====================================================

router.get('/conteo-rapido/:id/excel', authMiddleware, async (req, res) => {
  try {
    const reporteId = req.params.id;

     // Self-healing: asegurar orden para todas las áreas activas de conteo rápido.
    // Usa area_id como orden base para mantener estabilidad con el orden natural de BD.
    await pool.query(
      `INSERT INTO conteo_rapido_area_orden (area_id, orden)
       SELECT a.id, a.id
       FROM areas a
       LEFT JOIN conteo_rapido_area_orden o ON o.area_id = a.id
       WHERE a.es_conteo_rapido = 1
         AND a.activo = 1
         AND o.area_id IS NULL`
    );

    // 1️⃣ Traer cabecera del reporte
    const [[reporte]] = await pool.query(
      `
      SELECT r.fecha, r.turno, u.nombre AS planillero
      FROM reportes r
      JOIN users u ON u.id = r.creado_por_user_id
      WHERE r.id = ?
    `,
      [reporteId]
    );

    if (!reporte) {
      return res.status(404).json({ error: 'Reporte no existe' });
    }

    // 2️⃣ Traer detalle por área
    const [detalles] = await pool.query(
      `
      SELECT a.nombre AS area, d.cantidad
      FROM conteo_rapido_detalle d
      JOIN areas a ON a.id = d.area_id
      LEFT JOIN conteo_rapido_area_orden o ON o.area_id = a.id
      WHERE d.reporte_id = ?
      AND COALESCE(d.cantidad, 0) > 0
      ORDER BY COALESCE(o.orden, 999999) ASC, a.id ASC
    `,
      [reporteId]
    );

    const workbook = new ExcelJS.Workbook();
    const sheet = workbook.addWorksheet('Reporte Personal');

    /* =============================
       ESTILOS
    ============================= */
    const thinBorder = {
      top: { style: 'thin' },
      left: { style: 'thin' },
      bottom: { style: 'thin' },
      right: { style: 'thin' },
    };

    const headerBlue = {
      type: 'pattern',
      pattern: 'solid',
      fgColor: { argb: '1F4E78' },
    };

    const applyBorderRow = (rowNumber) => {
      sheet.getRow(rowNumber).eachCell({ includeEmpty: true }, (cell) => {
        cell.border = thinBorder;
      });
    };

    const applyBorderRangeAB = (startRow, endRow) => {
      for (let r = startRow; r <= endRow; r++) {
        sheet.getRow(r).getCell(1).border = thinBorder; // A
        sheet.getRow(r).getCell(2).border = thinBorder; // B
      }
    };

    /* =============================
       TÍTULO
    ============================= */
    sheet.mergeCells('A1:B1');
    sheet.getCell('A1').value = 'REPORTE PERSONAL';
    sheet.getCell('A1').fill = headerBlue;
    sheet.getCell('A1').font = { bold: true, color: { argb: 'FFFFFF' } };
    sheet.getCell('A1').alignment = { horizontal: 'center' };

    // Bordes del título (al estar merge, ponemos borde a A1 y B1)
    sheet.getCell('A1').border = thinBorder;
    sheet.getCell('B1').border = thinBorder;

    /* =============================
       CABECERA
    ============================= */
    sheet.addRow(['DiA:', reporte.fecha.toISOString().slice(0, 10)]);
    sheet.addRow(['TURNO:', reporte.turno]);
    sheet.addRow(['PLANILLERO:', reporte.planillero]);

    // Bordes en filas de cabecera (2,3,4)
    applyBorderRangeAB(2, 4);

    // Fila vacía
    sheet.addRow([]);
    // Si quieres que la fila vacía también tenga líneas, descomenta:
    // applyBorderRow(5);

    /* =============================
       TABLA
    ============================= */
    const tableStartRow = sheet.rowCount + 1; // donde empieza "AREA | N° Personas"

    sheet.addRow(['AREA', 'N° Personas']);
    const headerRowNumber = sheet.lastRow.number;

    sheet.getRow(headerRowNumber).eachCell({ includeEmpty: true }, (cell) => {
      cell.fill = headerBlue;
      cell.font = { bold: true, color: { argb: 'FFFFFF' } };
      cell.alignment = { horizontal: 'center' };
      cell.border = thinBorder;
    });

    let total = 0;

    detalles.forEach((d) => {
      const qty = Number(d.cantidad) || 0;
      total += qty;

      sheet.addRow([d.area, qty]);
      const r = sheet.lastRow.number;

      // Bordes por fila de datos
      sheet.getRow(r).getCell(1).border = thinBorder;
      sheet.getRow(r).getCell(2).border = thinBorder;

      // Alineación (opcional)
      sheet.getRow(r).getCell(1).alignment = { horizontal: 'left' };
      sheet.getRow(r).getCell(2).alignment = { horizontal: 'right' };
    });

    /* =============================
       TOTAL
    ============================= */
    sheet.addRow(['TOTAL:', total]);
    const totalRowNumber = sheet.lastRow.number;

    sheet.getRow(totalRowNumber).font = { bold: true };
    sheet.getRow(totalRowNumber).getCell(1).border = thinBorder;
    sheet.getRow(totalRowNumber).getCell(2).border = thinBorder;

    // Si quieres el TOTAL con fondo gris (opcional)
    // sheet.getRow(totalRowNumber).eachCell({ includeEmpty: true }, (cell) => {
    //   cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'D9D9D9' } };
    // });

    // Por si quieres asegurar bordes en todo el bloque de tabla:
    const tableEndRow = sheet.rowCount;
    applyBorderRangeAB(tableStartRow, tableEndRow);

    // 🔘 Fila TOTAL en gris
    sheet.getRow(totalRowNumber).eachCell({ includeEmpty: true }, (cell) => {
      cell.fill = {
        type: 'pattern',
        pattern: 'solid',
        fgColor: { argb: 'D9D9D9' }, // gris claro tipo Excel
      };

      cell.font = { bold: true };

      cell.border = {
        top: { style: 'thin' },
        left: { style: 'thin' },
        bottom: { style: 'thin' },
        right: { style: 'thin' },
      };

      cell.alignment = {
        vertical: 'middle',
        horizontal: cell.col === 2 ? 'right' : 'left',
      };
    });


    /* =============================
       ANCHOS
    ============================= */
    sheet.columns = [{ width: 55 }, { width: 25 }];

    /* =============================
       RESPUESTA
    ============================= */
    res.setHeader(
      'Content-Type',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    );
    res.setHeader(
      'Content-Disposition',
      `attachment; filename=reporte_conteo_${reporteId}.xlsx`
    );

    await workbook.xlsx.write(res);
    res.end();
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: e.message || 'Error generando Excel' });
  }
});



/* ===============================================
   GET /reportes/:id/pdf  (antes que /:id)
=============================================== */
router.get("/:id/pdf", authMiddleware, async (req, res) => {
  try {
    const { id } = req.params;

    // CABECERA
    const [rows] = await pool.query(
      `SELECT
         r.id,
         r.fecha,
         r.turno,
         r.tipo_reporte,
         r.creado_por_user_id,
         r.creado_por_nombre,
         r.observaciones
       FROM reportes r
       WHERE r.id = ?
       LIMIT 1`,
      [id]
    );

    if (!rows.length) {
      return res.status(404).json({ error: "Reporte no encontrado" });
    }

    const reporte = rows[0];

    // Seguridad: si no es admin, solo lo suyo
    const role =
      Array.isArray(req.user.roles) && req.user.roles.length
        ? req.user.roles[0]
        : undefined;

    if (role !== "ADMINISTRADOR" && reporte.creado_por_user_id !== req.user.id) {
      return res.status(403).json({ error: "No autorizado" });
    }

    // LÍNEAS
    const [lineasRaw] = await pool.query(
      `
      SELECT
        lr.trabajador_codigo,
        lr.trabajador_nombre,
        lr.hora_inicio,
        lr.hora_fin,
        lr.horas,
        lr.labores,
        COALESCE(lr.area_nombre, a.nombre) AS area_apoyo
      FROM lineas_reporte lr
      LEFT JOIN areas a ON a.id = lr.area_id
      WHERE lr.reporte_id = ?
      ORDER BY lr.id ASC
      `,
      [id]
    );

     const lineas = await hidratarTrabajadoresPorCodigo(lineasRaw);

    // Plantilla por tipo
    const templateNameByTipo = {
      APOYO_HORAS: "apoyos_horas.html",
      CONTEO_RAPIDO: "conteo_rapido.html",
      TRABAJO_AVANCE: "trabajo_avance.html",
      SANEAMIENTO: "saneamiento.html",
    };

    const templateName =
      templateNameByTipo[reporte.tipo_reporte] || "apoyos_horas.html";
    const templatePath = path.join(__dirname, "../templates", templateName);

    let html = fs.readFileSync(templatePath, "utf8");

    const d = new Date(reporte.fecha);
      const fechaTxt = Number.isNaN(d.getTime())
        ? ""
        : d.toLocaleDateString("es-PE", {
            day: "2-digit",
            month: "2-digit",
            year: "numeric",
          });

    // ======================================================
// ✅ TRABAJO_AVANCE: PDF por cuadrillas (no usa lineas_reporte)
// ======================================================
if (reporte.tipo_reporte === "TRABAJO_AVANCE") {

  const toNum = (v) => {
    if (v === null || v === undefined) return 0;
    if (typeof v === "number") return v;
    const n = Number(String(v).trim().replace(",", "."));
    return Number.isFinite(n) ? n : 0;
  };

  const fmt2 = (n) => toNum(n).toFixed(2);
  const filcar = (kg) => toNum(kg).toFixed(2);
  const desu = (kg) => toNum(kg).toFixed(2);
  const alet = (kg) => toNum(kg).toFixed(2);

  

  const diffHours = (hi, hf) => {
    try {
      return calcularDiferenciaMinutos(hi, hf) / 60;
    } catch (_) {
      return 0;
    }
  };

  const filetecal = (kg) => {
    const k = Number(kg);
    const resultado = k  * 0.48 * 0.80;
    return resultado;
  }

  const desucal = (kg) => {
    const d = Number(kg);
    const resuldesu = d * 0.15 * 0.82;
    return resuldesu;
  }

  const aleta = (kg) => {
    const f = Number(kg);
    const resultadoaleta = f * 0.16 * 0.90;
    return resultadoaleta;
  }


  // 1) cuadrillas del reporte
  const [cuadrillas] = await pool.query(
    `SELECT id, reporte_id, tipo, nombre, hora_inicio, hora_fin, produccion_kg, apoyo_de_cuadrilla_id
     FROM trabajo_avance_cuadrillas
     WHERE reporte_id = ?
     ORDER BY tipo ASC, id ASC`,
    [id]
  );

  const [trabajadoresRaw] = await pool.query(
    `SELECT
       tav.id,
       tav.cuadrilla_id,
       TRIM(tav.trabajador_codigo) AS trabajador_codigo,
        tav.trabajador_nombre,
       tav.kg
     FROM trabajo_avance_trabajadores tav
     
     WHERE tav.cuadrilla_id IN (
       SELECT id FROM trabajo_avance_cuadrillas WHERE reporte_id = ?
     )
     ORDER BY tav.cuadrilla_id ASC, tav.id ASC`,
    [id]
  );
  const trabajadores = await hidratarTrabajadoresPorCodigo(trabajadoresRaw);

  // agrupar trabajadores por cuadrilla
  const workersByCuadrilla = new Map();
  for (const w of trabajadores) {
    const cid = Number(w.cuadrilla_id);
    if (!workersByCuadrilla.has(cid)) workersByCuadrilla.set(cid, []);
    workersByCuadrilla.get(cid).push(w);
  }

  // helpers HTML
  const escapeHtml = (s) =>
    String(s ?? "")
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;");

  const codeBoxHtml = (title, codes, tolvaText = "") => {
    const list = (!codes || codes.length === 0)
      ? `<div class="muted">Sin códigos</div>`
      : `<div class="code-list">
          ${codes.map((c, i) => `
            <div class="center">${i + 1}</div>
            <div>${escapeHtml(String(c).trim())}</div>
          `).join("")}
        </div>`;

    return `
      <div class="code-box">
        <div class="hdr"> ${escapeHtml(title)}</div>
        <div class="sub">${escapeHtml(tolvaText)}</div>
        ${list}
      </div>
    `;
  };

  // ===========================
  // TABLA PRINCIPAL (estilo hoja)
  // ===========================
  // Filas: recepcion + fileteado (solo esos dos tipos en tabla principal)
  const tablaRows = cuadrillas
    .filter(c => c.tipo === "RECEPCION" || c.tipo === "FILETEADO")
    .map(c => {
      const ws = workersByCuadrilla.get(Number(c.id)) || [];
      const pers = ws.length;

      const kgBase = toNum(c.produccion_kg);
      const usaKg = c.tipo === "RECEPCION" || c.tipo === "FILETEADO";
      const kg = usaKg ? kgBase : 0;
      const resultadoFilete = c.tipo === "FILETEADO" ? filetecal(kg) : 0;
      const resultadodesu = c.tipo === "FILETEADO" ? desucal(kg) : 0;
      const resultadoaleta1 = c.tipo === "FILETEADO" ? aleta(kg) : 0;
       
      const hi = c.hora_inicio ? String(c.hora_inicio).slice(0,5) : "";
      const hf = c.hora_fin ? String(c.hora_fin).slice(0,5) : "";
      const he = diffHours(c.hora_inicio, c.hora_fin);

      const kgHrsPers = (pers > 0 && he > 0) ? (kg / (he * pers)) : 0;

      return {
        tipo: c.tipo,
        nombre: String(c.nombre || ""),
        pers,
        kg,
        resultado:resultadoFilete,
        resuldesu:resultadodesu,
        resultadoaleta:resultadoaleta1,
        hi,
        hf,
        he,
        kgHrsPers
      };
    });

  const tablaRowsFileteado = tablaRows.filter((r) => r.tipo === "FILETEADO");

  const totalPers = tablaRows.reduce((a,r)=> a + (r.pers||0), 0);
  const totalKg   = tablaRows.reduce((a,r)=> a + (r.kg||0), 0);
  const totalfile = tablaRows.reduce((a,r) => a + (r.resultado || 0), 0);
  const totaldes = tablaRows.reduce((a,r) => a + (r.resuldesu || 0), 0);
  const totalaleta = tablaRows.reduce((a,r) => a + (r.resultadoaleta || 0), 0);
  const totalHe   = tablaRows.reduce((a,r)=> a + (r.he||0), 0);
  const totalKgHrsPers = (totalPers > 0 && totalHe > 0) ? (totalKg / (totalHe * totalPers)) : 0;
  
  // Nota: tu hoja tiene columnas (Descarga, Fileteado, Desuñado, Aleta).
  // En tu app hoy solo tenemos “produccion_kg”.
  // Para que el formato quede igual, ponemos produccion_kg en “DESCARGA (KG)”
  // y dejamos el resto en blanco.
  const tablaHtml = `
    <table>
      <thead>
        <tr>
          <th style="width:40px;"></th>
          <th>CUADRILLA</th>
          <th style="width:70px;"># PERS.</th>
          <th style="width:120px;">DESCARGA (KG)</th>
          <th style="width:90px;">FILETEADO</th>
          <th style="width:90px;">DESUÑADO</th>
          <th style="width:90px;">ALETA</th>
          <th style="width:60px;">H.I</th>
          <th style="width:60px;">H.F</th>
          <th style="width:60px;">H.E</th>
          <th style="width:80px;">KG/HRS/PERS</th>
        </tr>
      </thead>
      <tbody>
        ${tablaRows.map((r, idx) => `
          <tr>
            <td class="center">${idx + 1}</td>
            <td>${escapeHtml(r.nombre)}</td>
            <td class="center">${r.pers}</td>
            <td class="num">${fmt2(r.kg)}</td>
            <td class="num">${filcar(r.resultado)}</td>
            <td class="num">${desu(r.resuldesu)}</td>
            <td class="num">${alet(r.resultadoaleta)}</td>
            <td class="center">${escapeHtml(r.hi)}</td>
            <td class="center">${escapeHtml(r.hf)}</td>
            <td class="num">${fmt2(r.he)}</td>
            <td class="num">${fmt2(r.kgHrsPers)}</td>
          </tr>
        `).join("")}
        <tr class="row-total">
          <td></td>
          <td class="center">TOTAL</td>
          <td class="center">${totalPers}</td>
          <td class="num">${fmt2(totalKg)}</td>
          <td class="num">${filcar(totalfile)}</td>
          <td class="num">${desu(totaldes)}</td>
          <td class="num">${alet(totalaleta)}</td>
          <td></td>
          <td></td>
          <td class="num">${fmt2(totalHe)}</td>
          <td class="num">${fmt2(totalKgHrsPers)}</td>
        </tr>
      </tbody>
    </table>
  `;

  // ===========================
  // CÓDIGOS: por sección
  // ===========================
  const cuadrillasRecep = cuadrillas.filter(c => c.tipo === "RECEPCION");
  const cuadrillasFilet = cuadrillas.filter(c => c.tipo === "FILETEADO");
  const cuadrillasApoyo = cuadrillas.filter(c => c.tipo === "APOYO_RECEPCION");

  const buildBoxes = (arr) => {
    if (!arr.length) return `<div class="muted">Sin registros</div>`;
    return arr.map(c => {
      const ws = workersByCuadrilla.get(Number(c.id)) || [];
      // Solo códigos (como en la hoja)
      const codes = ws.map(w => String(w.trabajador_codigo || "").trim()).filter(Boolean);

      // Si después quieres "código + nombre", dime y lo cambio
      return codeBoxHtml(String(c.nombre||""), codes, "");
    }).join("");
  };

  const codRecepHtml = buildBoxes(cuadrillasRecep);
  const codFiletHtml = buildBoxes(cuadrillasFilet);
  const codApoyoHtml = buildBoxes(cuadrillasApoyo);

  // ===========================
  // Meta: día, fecha, etc
  // ===========================
  const fechaObj = new Date(reporte.fecha);
  const diaTxt = Number.isNaN(fechaObj.getTime())
    ? ""
    : fechaObj.toLocaleDateString("es-PE", { weekday: "long" });

  const fechaTxt = Number.isNaN(fechaObj.getTime())
    ? ""
    : fechaObj.toLocaleDateString("es-PE", { day: "2-digit", month: "2-digit", year: "numeric" });

  // Turno puede venir "Dia" en BD; lo quieres como en hoja
  const turnoTxt = (reporte.turno || "").toString();

  // ===========================
  // Logo embebido (data uri)
  // ===========================
  // Pon tu logo en: src/templates/assets/logo.png (o cambia la ruta)
  const logoPath = path.join(__dirname, "../templates/assets/logo.png");
  let logoDataUri = "";
  try {
    const img = fs.readFileSync(logoPath);
    logoDataUri = `data:image/png;base64,${img.toString("base64")}`;
  } catch (e) {
    logoDataUri = ""; // si no hay logo, queda vacío
  }

  // 3) render html
  const templatePath = path.join(__dirname, "../templates/trabajo_avance.html");
  let html = fs.readFileSync(templatePath, "utf8");

  html = html
    .replaceAll("{{LOGO_DATA_URI}}", logoDataUri)
    .replaceAll("{{DIA}}", diaTxt ? diaTxt.charAt(0).toUpperCase() + diaTxt.slice(1) : "")
    .replaceAll("{{FECHA}}", fechaTxt)
    .replaceAll("{{TURNO}}", escapeHtml(turnoTxt))
    .replaceAll("{{PLANILLERO}}", escapeHtml(reporte.creado_por_nombre || ""))
    .replaceAll("{{TABLA_PRINCIPAL}}", tablaHtml)
    .replaceAll("{{CODIGOS_RECEPCION}}", codRecepHtml)
    .replaceAll("{{CODIGOS_FILETEADO}}", codFiletHtml)
    .replaceAll("{{CODIGOS_APOYO}}", codApoyoHtml);

  // 4) PDF
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.setContent(html, { waitUntil: "networkidle" });

  const pdfBuffer = await page.pdf({
    format: "A4",
    printBackground: true,
    margin: { top: "10mm", right: "10mm", bottom: "10mm", left: "10mm" },
  });

  await browser.close();

  res.setHeader("Content-Type", "application/pdf");
  res.setHeader(
    "Content-Disposition",
    `attachment; filename="reporte_trabajo_avance_${id}.pdf"`
  );
  return res.send(pdfBuffer);
}




    const filasHtml = lineas
      .map((l, i) => {
        const hIni = l.hora_inicio ? String(l.hora_inicio).slice(0, 5) : "";
        const hFin = l.hora_fin ? String(l.hora_fin).slice(0, 5) : "";
        const horas = formatearTotalHorasParaPdf(l);
        const codigo = (l.trabajador_codigo ?? "").toString().trim();
        const nombre = l.trabajador_nombre ?? "";
        const labores = (l.labores ?? "").toString();
        const areaOlabores =
        reporte.tipo_reporte === "SANEAMIENTO" ? labores : (l.area_apoyo ?? "");


        return `
          <tr>
            <td class="c">${i + 1}</td>
            <td class="c">${codigo}</td>
            <td>${nombre}</td>
            <td class="c">${hIni}</td>
            <td class="c">${hFin}</td>
            <td class="c">${horas}</td>
            <td>${areaOlabores}</td>
          </tr>
        `;
      })
      .join("");

    html = html
      .replaceAll("{{FECHA}}", fechaTxt)
      .replaceAll("{{TURNO}}", reporte.turno || "")
      .replaceAll("{{PLANILLERO}}", reporte.creado_por_nombre || "")
      .replaceAll("{{FILAS}}", filasHtml)
      .replaceAll("{{OBSERVACIONES_BLOQUE}}", (() => {
        if (!["APOYO_HORAS", "SANEAMIENTO"].includes(reporte.tipo_reporte)) return "";
        const observacionesTexto = String(reporte.observaciones ?? "").trim();
        if (!observacionesTexto) return "";
        const observacionesHtml = observacionesTexto
          .replaceAll("&", "&amp;")
          .replaceAll("<", "&lt;")
          .replaceAll(">", "&gt;")
          .replaceAll('"', "&quot;")
          .replaceAll("'", "&#039;")
          .replaceAll("\n", "<br>");
        return `<div style="margin-top:12px;"><div style="font-weight:700; margin-bottom:4px;">OBSERVACIONES</div><div>${observacionesHtml}</div></div>`;
      })());

    const browser = await chromium.launch();
    const page = await browser.newPage();

    await page.setContent(html, { waitUntil: "networkidle" });

    const pdfBuffer = await page.pdf({
      format: "A4",
      printBackground: true,
      margin: { top: "10mm", right: "10mm", bottom: "10mm", left: "10mm" },
    });

    await browser.close();

    res.setHeader("Content-Type", "application/pdf");
    res.setHeader(
      "Content-Disposition",
      `attachment; filename="reporte_${String(reporte.tipo_reporte).toLowerCase()}_${id}.pdf"`
    );
    return res.send(pdfBuffer);
  } catch (err) {
    console.error("Error PDF:", err);
    if (err?.code === "TRABAJADOR_NO_ENCONTRADO") {
      return res.status(404).json({ error: "TRABAJADOR_NO_ENCONTRADO" });
    }
    return res.status(500).json({ error: "Error generando PDF" });
  }
});

/* =======================================
   GET /reportes/:id (cabecera)
======================================= */
router.get("/:id", authMiddleware, async (req, res) => {
  try {
    const { id } = req.params;

    const [rows] = await pool.query(
      `SELECT
         r.id,
         r.fecha,
         r.turno,
         r.tipo_reporte,
         r.area_id,
         r.activo,
         r.estado,
         r.vence_en,
         r.cerrado_en,
         a.nombre AS area_nombre,
         r.creado_por_user_id,
         r.creado_por_nombre,
         r.observaciones,
         r.creado_en
       FROM reportes r
       LEFT JOIN areas a ON r.area_id = a.id
       WHERE r.id = ?
       LIMIT 1`,
      [id]
    );

    if (!rows.length) {
      return res.status(404).json({ error: "Reporte no encontrado" });
    }

    // (opcional) seguridad: si no es admin, solo lo suyo
    const role =
      Array.isArray(req.user.roles) && req.user.roles.length
        ? req.user.roles[0]
        : undefined;

    if (role !== "ADMINISTRADOR" && rows[0].creado_por_user_id !== req.user.id) {
      return res.status(403).json({ error: "No autorizado" });
    }

    return res.json(rows[0]);
  } catch (err) {
    console.error("Error al obtener reporte:", err);
    return res
      .status(500)
      .json({ error: "Error interno al obtener el reporte" });
  }
});

/* ======================================
   POST /reportes  (crear cabecera)
====================================== */
router.post("/", authMiddleware, async (req, res) => {
  try {
    const { fecha, turno, tipo_reporte, area_id, observaciones } = req.body;
    let observacionesSanitizadas = null;
    try {
      const observacionesPayload = sanitizarObservaciones(observaciones);
      if (
        observacionesPayload.provided &&
        !["APOYO_HORAS", "SANEAMIENTO"].includes(tipo_reporte)
      ) {
        return res.status(400).json({
          error: "observaciones solo aplica para APOYO_HORAS y SANEAMIENTO",
        });
      }
      observacionesSanitizadas = observacionesPayload.value;
    } catch (error) {
      if (error?.code === "OBSERVACIONES_TOO_LONG") {
        return res.status(400).json({ error: error.message });
      }
      throw error;
    }
    const creado_por_user_id = req.user.id;

    if (!fecha || !turno || !tipo_reporte) {
      return res.status(400).json({
        error: "Faltan campos obligatorios: fecha, turno, tipo_reporte",
      });
    }

    const turnoNormalizado = normalizarTurno(turno);

    if (!esTurnoValido(turnoNormalizado)) {
      return res.status(400).json({ error: "turno no válido" });
    }

    if (!esTipoReporteValido(tipo_reporte)) {
      return res.status(400).json({ error: "tipo_reporte no válido" });
    }

    const [urows] = await pool.query(
      "SELECT nombre, username FROM users WHERE id = ? AND activo = 1 LIMIT 1",
      [creado_por_user_id]
    );

    if (!urows.length) {
      return res.status(401).json({ error: "Usuario inválido o desactivado" });
    }

    const creado_por_nombre = urows[0].nombre || urows[0].username;

    // area_id solo se requiere en algunos tipos
    const requiereAreaEnCabecera = ["TRABAJO_AVANCE", "CONTEO_RAPIDO"].includes(
      tipo_reporte
    );

    // En APOYO_HORAS el área va por trabajador (líneas)
    // En SANEAMIENTO no se usa área
    if (requiereAreaEnCabecera && (area_id === null || area_id === undefined)) {
      return res.status(400).json({
        error: "Para este tipo_reporte se requiere area_id",
      });
    }

    let areaNombre = null;
    let areaIdFinal = null;

    if (requiereAreaEnCabecera) {
      if (!area_id) {
        return res.status(400).json({
          error:
            "Para este tipo_reporte se requiere area_id (en APOYO_HORAS el área va por trabajador).",
        });
      }

      const flag = flagParaTipoReporte(tipo_reporte);
      if (!flag) {
        return res.status(400).json({
          error: "No se pudo determinar el módulo para ese tipo_reporte",
        });
      }

      const [areas] = await pool.query(
        `SELECT id, nombre
         FROM areas
         WHERE id = ? AND ${flag} = 1 AND activo = 1
         LIMIT 1`,
        [area_id]
      );

      if (!areas.length) {
        return res.status(400).json({
          error: "El área seleccionada no es válida para este tipo de reporte",
        });
      }

      areaNombre = areas[0].nombre;
      areaIdFinal = areas[0].id;
    } else {
      if (tipo_reporte === "APOYO_HORAS") {
        areaNombre = "POR_TRABAJADOR";
        areaIdFinal = null;
      } else if (tipo_reporte === "SANEAMIENTO") {
        areaNombre = "SANEAMIENTO";
        areaIdFinal = null;
      } else {
        areaNombre = null;
        areaIdFinal = null;
      }
    }
     if (areaNombre === null && esTipoReporteValido(tipo_reporte)) {
      return res.status(400).json({
        error: "No se pudo determinar el área para el tipo de reporte",
      });
    }

    // ✅ estado/vence_en (24h) para módulos con “espera”
    const usaEspera24h = ["APOYO_HORAS", "SANEAMIENTO"].includes(tipo_reporte);

    const [result] = await pool.query(
      `INSERT INTO reportes
       (fecha, turno, tipo_reporte, area, area_id,
        creado_por_user_id, creado_por_nombre, observaciones,
        estado, vence_en)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?,
               ?, ?)`,
      [
        fecha,
        turnoNormalizado,
        tipo_reporte,
        areaNombre,
        areaIdFinal,
        creado_por_user_id,
        creado_por_nombre,
        observacionesSanitizadas,
        "ABIERTO",
        usaEspera24h ? new Date(Date.now() + 24 * 60 * 60 * 1000) : null,
      ]
    );

    return res.status(201).json({
      message: "Reporte creado correctamente",
      reporte_id: result.insertId,
      area_nombre: areaNombre,
      creado_por: { id: creado_por_user_id, nombre: creado_por_nombre },
    });
  } catch (err) {
    console.error("Error al crear reporte:", err);
    return res.status(500).json({ error: "Error interno al crear el reporte" });
  }
});



/* =====================================
   POST /reportes/:id/lineas
===================================== */
router.post("/:id/lineas", authMiddleware, async (req, res) => {
  try {
    console.log("[DEBUG][POST /reportes/:id/lineas] Content-Type:", req.headers["content-type"]);
    console.log("[DEBUG][POST /reportes/:id/lineas] Body recibido:", req.body);
    console.log("[DEBUG][POST /reportes/:id/lineas] trabajador_codigo:", req.body?.trabajador_codigo);
    console.log("[DEBUG][POST /reportes/:id/lineas] trabajador_nombre:", req.body?.trabajador_nombre);
    console.log("[DEBUG][POST /reportes/:id/lineas] trabajador_documento:", req.body?.trabajador_documento);
    console.log("[DEBUG][POST /reportes/:id/lineas] trabajador_id:", req.body?.trabajador_id);
    const reporteId = Number(req.params.id);
    if (!Number.isInteger(reporteId) || reporteId <= 0) {
      return res.status(400).json({ error: "id de reporte inválido" });
    }

    const {
      trabajador_id,
      trabajador_nombre,
      trabajador_codigo,
      trabajador_documento,
      cuadrilla_id,
      horas,
      hora_inicio,
      hora_fin,
      kilos,
      labores,
      area_id,
    } = req.body;

    
    const [repRows] = await pool.query(
      "SELECT id, tipo_reporte FROM reportes WHERE id = ? LIMIT 1",
      [reporteId]
    );
    if (!repRows.length) {
      return res.status(404).json({ error: "Reporte no encontrado" });
    }
    const tipo = repRows[0].tipo_reporte;

    // valores finales que se usarán en UPDATE/INSERT
    let areaNombre = null;
    let areaIdFinal = area_id ?? null;

    // reglas por tipo
    if (tipo === "SANEAMIENTO") {
      // saneamiento: NO área, PERO labores obligatorio
      if (!labores || !String(labores).trim()) {
        return res.status(400).json({
          error: "Para SANEAMIENTO se requiere 'labores'",
        });
      }
      // saneamiento no usa area_id
      areaIdFinal = null;
      areaNombre = null;
    }
    const trabajadorCodigoInput = String(trabajador_codigo ?? "").trim();
    const trabajadorNombreInput = String(trabajador_nombre ?? "").trim();
    const trabajadorDocumentoInput = String(trabajador_documento ?? "").trim();
    const trabajadorIdInput = String(trabajador_id ?? "").trim();
    const trabajadorIdEsNumerico =
      Boolean(trabajadorIdInput) && !Number.isNaN(Number(trabajadorIdInput));
  
    const tieneCodigoNombre =
      Boolean(trabajadorCodigoInput) && Boolean(trabajadorNombreInput);
    const tieneDocumento = Boolean(trabajadorDocumentoInput);
    //const usarIdComoCodigo = !trabajadorCodigoInput && !tieneDocumento && trabajadorIdEsNumerico;
    const tieneReferencia =
      Boolean(trabajadorCodigoInput) || Boolean(trabajadorDocumentoInput) || trabajadorIdEsNumerico;


     if (!tieneCodigoNombre && !tieneReferencia) {
       console.log(
        "[DEBUG][POST /reportes/:id/lineas] TRABAJADOR_NO_ENCONTRADO: !tieneCodigoNombre && !tieneReferencia",
        {
          trabajadorCodigoInput,
          trabajadorNombreInput,
          trabajadorDocumentoInput,
        }
      );
      return res.status(400).json({ error: "TRABAJADOR_NO_ENCONTRADO" });
    }

    let trabajadorIdFinal = trabajadorIdEsNumerico ? Number(trabajadorIdInput) : null;
    let trabajadorCodigoFinal = trabajadorCodigoInput;
    let trabajadorNombreFinal = trabajadorNombreInput;
    const trabajadorDocumentoFinal = trabajadorDocumentoInput || null;

      if (trabajadorIdEsNumerico) {
      trabajadorIdFinal = Number(trabajadorIdInput);
      trabajadorCodigoFinal = String(trabajadorIdFinal);
      if (!trabajadorNombreFinal) {
        trabajadorNombreFinal = "";
      }
      console.log("[DEBUG][POST /reportes/:id/lineas] Fuente trabajador:", {
        fuente: "trabajador_id",
        trabajador_id: trabajadorIdFinal,
        trabajador_codigo: trabajadorCodigoFinal,
      });
    } else if (tieneCodigoNombre) {
      console.log("[DEBUG][POST /reportes/:id/lineas] Fuente trabajador:", {
        fuente: "codigo+nombre",
        trabajador_codigo: trabajadorCodigoFinal,
        trabajador_nombre: trabajadorNombreFinal,
      });
    } else if (tieneDocumento) {
      console.log("[DEBUG][POST /reportes/:id/lineas] Fuente trabajador:", {
        fuente: "dni",
        trabajador_documento: trabajadorDocumentoFinal,
      });
      let trabajador = null;
      try {
        trabajador = await getTrabajadorPorCodigo(trabajadorDocumentoFinal);
      } catch (error) {
          console.error("[DEBUG][POST /reportes/:id/lineas] Error lookup trabajador:", {
          code: error?.code,
          message: error?.message,
        });
        if (error?.code === "TRABAJADOR_NO_ENCONTRADO") {
          return res
            .status(400)
            .json({ error: "TRABAJADOR_DOCUMENTO_INVALIDO" });
        }
        throw error;
      }

      console.log(
        "[DEBUG][POST /reportes/:id/lineas] Resultado trabajador:",
        {
          codigo: trabajador?.codigo ?? null,
          nombre: trabajador?.nombre ?? trabajador?.nombre_completo ?? null,
          dni: trabajador?.dni ?? null,
        }
      );

      
      trabajadorCodigoFinal = (trabajador?.codigo ?? "").toString().trim();
      trabajadorNombreFinal =
        trabajador?.nombre ?? trabajador?.nombre_completo ?? "";
    } else if (trabajadorCodigoInput) {
       trabajadorCodigoFinal = trabajadorCodigoInput;
      if (!trabajadorNombreFinal) {
        trabajadorNombreFinal = "";
      }
      console.log("[DEBUG][POST /reportes/:id/lineas] Fuente trabajador:", {
        fuente: "codigo_directo",
        trabajador_codigo: trabajadorCodigoFinal,
        
      });
    }
    

    // área solo para APOYO_HORAS
    if (tipo === "APOYO_HORAS") {
      if (!area_id) {
        return res
          .status(400)
          .json({ error: "area_id es obligatorio para APOYO_HORAS" });
      }

      const [aRows] = await pool.query(
        `SELECT id, nombre
         FROM areas
         WHERE id = ?
           AND es_apoyo_horas = 1
           AND activo = 1
         LIMIT 1`,
        [area_id]
      );

      if (!aRows.length) {
        return res
          .status(400)
          .json({ error: "Área no válida para APOYO_HORAS" });
      }

      areaNombre = aRows[0].nombre;
      areaIdFinal = aRows[0].id;

      if (!hora_inicio) {
        return res
          .status(400)
          .json({ error: "Para APOYO_HORAS se requiere hora_inicio" });
      }
    }

    // validar cuadrilla (si mandan)
    if (cuadrilla_id !== undefined && cuadrilla_id !== null) {
      const [cRows] = await pool.query(
        "SELECT id FROM cuadrillas WHERE id = ? AND reporte_id = ?",
        [cuadrilla_id, reporteId]
      );
      if (!cRows.length) {
        return res
          .status(400)
          .json({ error: "cuadrilla_id no válida para este reporte" });
      }
    }

    // calcular horas si llega hora_fin (solo APOYO_HORAS)
    let horasValue = horas ?? null;
    let horaFinValue = hora_fin ?? null;

    if (tipo === "APOYO_HORAS") {
      if (horaFinValue) {
         try {
          horasValue = calcularTotalHoras(hora_inicio, horaFinValue);
        } catch (error) {
          return res.status(400).json({ error: error.message });
        }
        
      } else {
        horasValue = null; // pendiente
      }
    }

     console.log("TEMP LOG (remover luego) POST /reportes/:id/lineas payload final", {
      reporteId,
      tipo,
      trabajador_id: trabajadorIdFinal,
      trabajador_codigo: trabajadorCodigoFinal,
      trabajador_nombre: trabajadorNombreFinal,
      trabajador_documento: trabajadorDocumentoFinal,
      cuadrilla_id: cuadrilla_id ?? null,
      area_id: areaIdFinal,
      area_nombre: areaNombre,
      hora_inicio: hora_inicio ?? null,
      hora_fin: horaFinValue,
      horas: horasValue,
      kilos: kilos ?? null,
      labores: labores ?? null,
    });

    // evitar duplicados por trabajador con pendiente (SANEAMIENTO)
    if (tipo === "SANEAMIENTO") {
        const pendientesParams = [reporteId];
      const pendientesCondiciones = [];
      if (trabajadorCodigoFinal) {
        pendientesCondiciones.push("trabajador_codigo = ?");
        pendientesParams.push(trabajadorCodigoFinal);
      }
      if (trabajadorDocumentoFinal) {
        pendientesCondiciones.push("trabajador_documento = ?");
        pendientesParams.push(trabajadorDocumentoFinal);
      }
      const whereTrabajador = pendientesCondiciones.length
        ? `AND (${pendientesCondiciones.join(" OR ")})`
        : "";

      const [pendiente] = await pool.query(
        `SELECT id
         FROM lineas_reporte
         WHERE reporte_id = ?
           ${whereTrabajador}
           AND hora_fin IS NULL
         ORDER BY id DESC
         LIMIT 1`,
         pendientesParams
      );

     if (pendiente.length) {
  const sets = [];
  const params = [];

  // 🔒 hora_inicio solo si viene (y no permitir setear null)
 if (hora_inicio !== undefined && hora_inicio !== null && String(hora_inicio).trim() !== "") {
  sets.push("hora_inicio = CASE WHEN hora_inicio IS NULL THEN ? ELSE hora_inicio END");
  params.push(hora_inicio);
}


  // hora_fin puede ir o quedar null (para cerrar o mantener pendiente)
  if (hora_fin !== undefined) {
    sets.push("hora_fin = ?");
    params.push(horaFinValue ?? null);
  }

  // horas
  if (horas !== undefined) {
    sets.push("horas = ?");
    params.push(horasValue ?? null);
  } else if (hora_fin !== undefined) {
    // si llegó hora_fin y calculaste horas, actualízalas
    sets.push("horas = ?");
    params.push(horasValue ?? null);
  }

  // labores (para saneamiento sí importa)
  if (labores !== undefined) {
    sets.push("labores = ?");
    params.push(labores ?? null);
  }

  if (!sets.length) {
    return res.status(400).json({ error: "No hay campos para actualizar" });
  }

  params.push(pendiente[0].id);

  await pool.query(
    `UPDATE lineas_reporte SET ${sets.join(", ")} WHERE id = ?`,
    params
  );

  const info = await recalcularEstadoReporte(reporteId);

  return res.json({
    message: "Linea actualizada (pendiente existente)",
    linea_id: pendiente[0].id,
    pendientes: info.pendientes,
    estado_reporte: info.estado,
  });
}

    }

    // ✅ evitar duplicados por trabajador con pendiente (APOYO_HORAS)
    if (tipo === "APOYO_HORAS") {
      const pendientesParams = [reporteId];
      const pendientesCondiciones = [];
      if (trabajadorCodigoFinal) {
        pendientesCondiciones.push("trabajador_codigo = ?");
        pendientesParams.push(trabajadorCodigoFinal);
      }
      if (trabajadorDocumentoFinal) {
        pendientesCondiciones.push("trabajador_documento = ?");
        pendientesParams.push(trabajadorDocumentoFinal);
      }
      const whereTrabajador = pendientesCondiciones.length
        ? `AND (${pendientesCondiciones.join(" OR ")})`
        : "";
      const [pendiente] = await pool.query(
        `SELECT id
         FROM lineas_reporte
         WHERE reporte_id = ?
            ${whereTrabajador}
           AND hora_fin IS NULL
         ORDER BY id DESC
         LIMIT 1`,
          pendientesParams
      );

      if (pendiente.length) {
        await pool.query(
          `UPDATE lineas_reporte
           SET area_id = ?,
               area_nombre = ?,
               hora_inicio = ?,
               hora_fin = ?,
               horas = ?
           WHERE id = ?`,
          [
            areaIdFinal,
            areaNombre,
            hora_inicio ?? null,
            horaFinValue,
            horasValue,
            pendiente[0].id,
          ]
        );

        const info = await recalcularEstadoReporte(reporteId);

        return res.json({
          message: "Linea actualizada (pendiente existente)",
          linea_id: pendiente[0].id,
          pendientes: info.pendientes,
          estado_reporte: info.estado,
        });
      }
    }

    // INSERT
    
    console.log(
      "[DEBUG][POST /reportes/:id/lineas] Valores finales antes INSERT:",
      {
        trabajador_codigo: trabajadorCodigoFinal,
        trabajador_nombre: trabajadorNombreFinal,
        trabajador_documento: trabajadorDocumentoFinal,
        trabajador_id: trabajadorIdFinal,
      }
    );
    if (trabajadorIdFinal !== null) {
      trabajadorCodigoFinal = String(trabajadorIdFinal);
    }


    const [result] = await pool.query(
      `INSERT INTO lineas_reporte
       (reporte_id, trabajador_id, cuadrilla_id, area_id, area_nombre,
        trabajador_codigo, trabajador_nombre, trabajador_documento,
        horas, hora_inicio, hora_fin, kilos, labores)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        reporteId,
        trabajadorIdFinal,
        cuadrilla_id ?? null,
        areaIdFinal, // ✅
        areaNombre, // ✅
        trabajadorCodigoFinal,
        trabajadorNombreFinal,
        trabajadorDocumentoFinal,
        horasValue,
        hora_inicio ?? null,
        horaFinValue,
        kilos ?? null,
        labores ?? null,
      ]
    );

    const info = await recalcularEstadoReporte(reporteId);

    return res.status(201).json({
      message: "Linea creada",
      linea_id: result.insertId,
      pendientes: info.pendientes,
      estado_reporte: info.estado,
    });
  } catch (err) {
    console.error("Error creando linea:", err);
    return res.status(500).json({ error: "Error interno al crear linea" });
  }
});

/* =====================================
   PUT /reportes/:id (actualizar)
===================================== */
router.put("/:id", authMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    const { fecha, turno, area_id, observaciones } = req.body;
    let observacionesSanitizadas;
    try {
      observacionesSanitizadas = sanitizarObservaciones(observaciones);
    } catch (error) {
      if (error?.code === "OBSERVACIONES_TOO_LONG") {
        return res.status(400).json({ error: error.message });
      }
      throw error;
    }

    const [rows] = await pool.query(
      "SELECT id, tipo_reporte FROM reportes WHERE id = ? LIMIT 1",
      [id]
    );
    if (!rows.length)
      return res.status(404).json({ error: "Reporte no encontrado" });

    const tipoReporte = rows[0].tipo_reporte;
    const updates = [];
    const params = [];

    if (fecha !== undefined) {
      updates.push("fecha = ?");
      params.push(fecha);
    }

    if (turno !== undefined) {
      const t = normalizarTurno(turno);
      if (!esTurnoValido(t))
        return res.status(400).json({ error: "turno no valido" });
      updates.push("turno = ?");
      params.push(t);
    }

    if (observacionesSanitizadas?.provided) {
      if (!["APOYO_HORAS", "SANEAMIENTO"].includes(tipoReporte)) {
        return res.status(400).json({
          error: "observaciones solo aplica para APOYO_HORAS y SANEAMIENTO",
        });
      }
      updates.push("observaciones = ?");
      params.push(observacionesSanitizadas.value);
    }

    // SANEAMIENTO no usa area_id en cabecera
    if (tipoReporte === "SANEAMIENTO") {
      if (area_id !== undefined) {
        return res.status(400).json({ error: "SANEAMIENTO no usa area_id" });
      }
    }

    let areaNombre = null;
    if (area_id !== undefined) {
      const flag = flagParaTipoReporte(tipoReporte);
      if (!flag) {
        return res.status(400).json({
          error: "No se pudo determinar el modulo para este tipo_reporte",
        });
      }

      const [areas] = await pool.query(
        `SELECT id, nombre
         FROM areas
         WHERE id = ? AND ${flag} = 1 AND activo = 1
         LIMIT 1`,
        [area_id]
      );

      if (!areas.length) {
        return res.status(400).json({
          error: "El area seleccionada no es valida para este tipo de reporte",
        });
      }

      areaNombre = areas[0].nombre;
      updates.push("area_id = ?");
      params.push(area_id);
      updates.push("area = ?");
      params.push(areaNombre);
    }

    if (!updates.length) {
      return res
        .status(400)
        .json({ error: "No hay campos editables para actualizar" });
    }

    params.push(id);
    await pool.query(
      `UPDATE reportes SET ${updates.join(", ")} WHERE id = ?`,
      params
    );

    return res.json({
      message: "REPORTE ACTUALIZADO CORRECTAMENTE",
      area_nombre: areaNombre,
    });
  } catch (err) {
    console.error("Error al actualizar reporte: ", err);
    return res
      .status(500)
      .json({ error: "Error interno al actualizar el reporte" });
  }
});



// TEST
router.get("/test", (req, res) => {
  res.json({ ok: true });
});

// ===============================================
// VER DETALLE DE UN REPORTE
// GET /reportes/conteo-rapido/:id
//==============================================
router.get("/conteo-rapido/:id", authMiddleware, async (req, res) => {
  try {
    const reporteId = Number(req.params.id);
    if (!reporteId) return res.status(400).json({ error: "id inválido" });

    const [cab] = await pool.query(
      `SELECT id, fecha, turno, estado, creado_por_nombre
       FROM reportes
       WHERE id = ? AND tipo_reporte = 'CONTEO_RAPIDO'
       LIMIT 1`,
      [reporteId]
    );
    if (cab.length === 0) return res.status(404).json({ error: "Reporte no encontrado" });

    const [det] = await pool.query(
      `SELECT d.area_id, a.nombre AS area_nombre, d.cantidad
       FROM conteo_rapido_detalle d
       JOIN areas a ON a.id = d.area_id
       LEFT JOIN conteo_rapido_area_orden o ON o.area_id = a.id
       WHERE d.reporte_id = ?
       ORDER BY COALESCE(o.orden, 9999), a.nombre`,
      [reporteId]
    );

    res.json({ reporte: cab[0], items: det });
  } catch (e) {
    res.status(500).json({ error: "Error consultando reporte", details: String(e) });
  }
});






/* ======================================
   PATCH /reportes/:id/activar
====================================== */
router.patch("/:id/activar", authMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    const { activo = 1 } = req.body;

    const activoValue = activo === 1 || activo === "1" ? 1 : 0;

    const [result] = await pool.query(
      "UPDATE reportes SET activo = ? WHERE id = ?",
      [activoValue, id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ error: "Reporte no encontrado" });
    }

    return res.json({
      message: "Estado del reporte actualizado",
      reporte_id: id,
      activo: activoValue,
    });
  } catch (err) {
    console.error("Error al actualizar reporte: ", err);
    return res
      .status(500)
      .json({ error: "Error interno al actualizar reporte " });
  }
});

/* =====================================
   GET /reportes  (listar)
===================================== */
router.get("/", authMiddleware, async (req, res) => {
  try {
    const {
      fecha,
      desde,
      hasta,
      tipo,
      area_id,
      turno,
      activo,
      creador_id,
      q,
      page = 1,
      limit = 20,
      ordenar = "fecha",
      dir = "desc",
    } = req.query;

    const camposOrden = new Set(["fecha", "creado_en"]);
    const dirs = new Set(["asc", "desc"]);
    const orderBy = camposOrden.has(ordenar) ? ordenar : "fecha";
    const orderDir = dirs.has(String(dir).toLowerCase())
      ? String(dir).toLowerCase()
      : "desc";

    const pageNum = Math.max(parseInt(page, 10) || 1, 1);
    const limitNum = Math.min(Math.max(parseInt(limit, 10) || 20, 1), 200);
    const offset = (pageNum - 1) * limitNum;

    const where = [];
    const params = [];

    const role =
      Array.isArray(req.user.roles) && req.user.roles.length
        ? req.user.roles[0]
        : undefined;

    if (role !== "ADMINISTRADOR") {
      where.push("r.creado_por_user_id = ?");
      params.push(req.user.id);
    }

    if (fecha) {
      where.push("DATE(r.fecha) = ?");
      params.push(String(fecha));
    } else {
      // si no mandan fecha, usa desde/hasta como antes
      if (desde) { where.push("r.fecha >= ?"); params.push(desde); }
      if (hasta) { where.push("r.fecha <= ?"); params.push(hasta); }
    }

    if (tipo) { where.push("r.tipo_reporte = ?"); params.push(tipo); }
    if (area_id) { where.push("r.area_id = ?"); params.push(area_id); }
    if (turno) { where.push("r.turno = ?"); params.push(normalizarTurno(turno)); }
    if (creador_id) { where.push("r.creado_por_user_id = ?"); params.push(creador_id); }

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
      params.push(normalizarTurno(turno));
    }
    if (creador_id) {
      where.push("r.creado_por_user_id = ?");
      params.push(creador_id);
    }

    if (q) {
      where.push(
        "(r.observaciones LIKE ? OR a.nombre LIKE ? OR r.creado_por_nombre LIKE ?)"
      );
      params.push(`%${q}%`, `%${q}%`, `%${q}%`);
    }

    if (activo !== undefined) {
      const activoNumber = Number(activo);
      if (Number.isNaN(activoNumber)) {
        return res
          .status(400)
          .json({ error: "El filtro 'activo' debe ser numérico (0 o 1)" });
      }
      const activoValue = activoNumber === 1 ? 1 : 0;
      where.push("r.activo = ?");
      params.push(activoValue);
    }

    const whereSql = where.length ? `WHERE ${where.join(" AND ")}` : "";

    const [countRows] = await pool.query(
      `SELECT COUNT(*) AS total
       FROM reportes r
       LEFT JOIN areas a ON a.id = r.area_id
       ${whereSql}`,
      params
    );

    const total = countRows[0]?.total || 0;
    const total_pages = Math.ceil(total / limitNum);

    const [rows] = await pool.query(
      `SELECT
         r.id,
         r.fecha,
         r.turno,
         r.tipo_reporte,
         r.area_id,
         r.activo,
         r.estado,
         r.vence_en,
         r.cerrado_en,
         a.nombre AS area_nombre,
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
