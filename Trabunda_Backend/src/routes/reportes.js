// src/routes/reportes.js
const express = require("express");
const router = express.Router();
const { pool } = require("../db");
const { authMiddleware } = require("../middlewares/auth");
const PDFDocument = require("pdfkit");
const fs = require("fs");
const path = require("path");
const { chromium } = require("playwright");


//const { width } = require("pdfkit/js/page");

/* =========================
   Helpers
========================= */

function esTipoReporteValido(tipo) {
  return [
    "SANEAMIENTO",
    "APOYO_HORAS",
    "TRABAJO_AVANCE",
    "CONTEO_RAPIDO",
  ].includes(tipo);
}

function normalizarTurno(turno) {
  if (!turno) return turno;
  const t = String(turno).trim();
  if (t === "Dia" || t === "DIA") return "Día";
  return t;
}

function esTurnoValido(turno) {
  const t = normalizarTurno(turno);
  // Ajusta aquí si luego agregas Mañana/Tarde
  return ["Noche", "Día", "Dia"].includes(t);
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

function flagParaTipoReporte(tipo) {
  switch (tipo) {
    case "APOYO_HORAS":
      return "es_apoyo_horas";
    case "TRABAJO_AVANCE":
      return "es_trabajo_avance";
    case "SANEAMIENTO":
      return "es_conteo_rapido"; // según tu nota
    default:
      return null;
  }
}

/* ===========================================================
   🔥 ORDEN IMPORTANTE (específicas primero)
=========================================================== */

/* ========================================
   GET /reportes/apoyo-horas/open
======================================== */
router.get("/apoyo-horas/open", authMiddleware, async (req, res) => {
  try {
    const userId = req.user.id;
    const turnoRaw = req.query.turno;
    const turno = normalizarTurno(turnoRaw);
    const { fecha } = req.query;

    if (!turno) return res.status(400).json({ error: "turno es requerido" });
    if (!esTurnoValido(turno))
      return res.status(400).json({ error: "turno no valido" });

    const fechaValue = fecha
      ? String(fecha)
      : new Date().toISOString().slice(0, 10);

    // 1) buscar si ya existe un ABIERTO vigente para ese usuario+turno+fecha
    const [rows] = await pool.query(
      `SELECT id, fecha, turno, estado, vence_en, creado_por_nombre
       FROM reportes
       WHERE tipo_reporte = 'APOYO_HORAS'
         AND creado_por_user_id = ?
         AND turno = ?
         AND fecha = ?
         AND estado = 'ABIERTO'
         AND (vence_en IS NULL OR vence_en > NOW())
       ORDER BY id DESC
       LIMIT 1`,
      [userId, turno, fechaValue]
    );

    if (rows.length) {
      return res.json({ existente: true, reporte: rows[0] });
    }

    // 2) si no existe, crear uno nuevo
    const [urows] = await pool.query(
      "SELECT nombre, username FROM users WHERE id = ? AND activo = 1 LIMIT 1",
      [userId]
    );
    if (!urows.length)
      return res.status(401).json({ error: "Usuario invalido o desactivado" });

    const creado_por_nombre = urows[0].nombre || urows[0].username;

    const [result] = await pool.query(
      `INSERT INTO reportes
       (fecha, turno, tipo_reporte, area, area_id,
        creado_por_user_id, creado_por_nombre, observaciones,
        estado, vence_en)
       VALUES (?, ?, 'APOYO_HORAS', 'POR_TRABAJADOR', NULL,
               ?, ?, NULL,
               'ABIERTO', DATE_ADD(NOW(), INTERVAL 24 HOUR))`,
      [fechaValue, turno, userId, creado_por_nombre]
    );

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
          COUNT(*) AS pendiente,
          MAX(lr.area_nombre) AS area_nombre
       FROM reportes r
       JOIN lineas_reporte lr ON lr.reporte_id = r.id
       WHERE r.tipo_reporte = 'APOYO_HORAS'
         AND r.creado_por_user_id = ?
         AND r.estado = 'ABIERTO'
         AND (r.vence_en IS NULL OR r.vence_en > NOW())
         AND lr.hora_fin IS NULL
       GROUP BY r.id
       ORDER BY r.id DESC`,
      [userId]
    );

    return res.json({ items: rows });
  } catch (err) {
    console.error("pendientes apoyo-horas error:", err);
    return res.status(500).json({ error: "Error interno de pendientes" });
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

    const {
      cuadrilla_id,
      horas,
      hora_inicio,
      hora_fin,
      kilos,
      labores,
      area_id,
    } = req.body;

    const [lineaRows] = await pool.query(
      "SELECT reporte_id, hora_inicio FROM lineas_reporte WHERE id = ? LIMIT 1",
      [lineaId]
    );
    if (!lineaRows.length) {
      return res.status(404).json({ error: "Linea no encontrada" });
    }

    const existingLinea = lineaRows[0];

    const updates = [];
    const params = [];

    if (cuadrilla_id !== undefined) {
      updates.push("cuadrilla_id = ?");
      params.push(cuadrilla_id ?? null);
    }
    if (hora_inicio !== undefined) {
      updates.push("hora_inicio = ?");
      params.push(hora_inicio ?? null);
    }
    if (hora_fin !== undefined) {
      updates.push("hora_fin = ?");
      params.push(hora_fin ?? null);
    }
    if (kilos !== undefined) {
      updates.push("kilos = ?");
      params.push(kilos ?? null);
    }
    if (labores !== undefined) {
      updates.push("labores = ?");
      params.push(labores ?? null);
    }

    // area (opcional)
    if (area_id !== undefined) {
      updates.push("area_id = ?");
      params.push(area_id ?? null);

      const [aRows] = await pool.query(
        "SELECT nombre FROM areas WHERE id = ? LIMIT 1",
        [area_id]
      );
      const areaNombre = aRows[0]?.nombre ?? null;
      updates.push("area_nombre = ?");
      params.push(areaNombre);
    }

    // recalcular horas si llega hora_fin y no mandan horas
    const horaFinLlego = hora_fin !== undefined;
    const horaFinValue = hora_fin ?? null;
    const horaInicioParaCalculo =
      hora_inicio !== undefined
        ? hora_inicio ?? null
        : existingLinea.hora_inicio;

    let horasCalculadas;
    if (horaFinLlego && horaFinValue && horaInicioParaCalculo) {
      const toMin = (s) => {
        const [h, m] = String(s).split(":");
        return Number(h) * 60 + Number(m);
      };
      const diff = toMin(horaFinValue) - toMin(horaInicioParaCalculo);
      if (diff <= 0) {
        return res
          .status(400)
          .json({ error: "hora_fin debe ser mayor que hora_inicio" });
      }
      horasCalculadas = diff / 60;
    }

    if (horas !== undefined) {
      const horasValue =
        horas === null && horaFinLlego
          ? horasCalculadas ?? null
          : horas ?? horasCalculadas ?? null;
      updates.push("horas = ?");
      params.push(horasValue);
    } else if (horaFinLlego && horasCalculadas !== undefined) {
      updates.push("horas = ?");
      params.push(horasCalculadas);
    }

    if (!updates.length) {
      return res.status(400).json({ error: "No hay campos para actualizar" });
    }

    params.push(lineaId);

    const [result] = await pool.query(
      `UPDATE lineas_reporte SET ${updates.join(", ")} WHERE id = ?`,
      params
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ error: "Linea no encontrada" });
    }

    // cerrar reporte si ya no hay pendientes
    const reporteId = existingLinea.reporte_id;
    if (reporteId) {
      const [pend] = await pool.query(
        "SELECT COUNT(*) AS c FROM lineas_reporte WHERE reporte_id = ? AND hora_fin IS NULL",
        [reporteId]
      );
      const pendientes = Number(pend[0]?.c ?? 0);
      if (pendientes === 0) {
        await pool.query(
          "UPDATE reportes SET estado = 'CERRADO', cerrado_en = NOW() WHERE id = ?",
          [reporteId]
        );
      }
    }

    return res.json({ message: "Linea actualizada" });
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

    const [result] = await pool.query(
      "DELETE FROM lineas_reporte WHERE id = ?",
      [lineaId]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ error: "Linea no encontrada" });
    }

    return res.json({ message: "Linea eliminada" });
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

         lr.trabajador_codigo,
         lr.trabajador_nombre,

         lr.area_id,
         lr.area_nombre,

         lr.hora_inicio,
         lr.hora_fin,
         lr.horas,

         lr.kilos,
         lr.labores,

         c.nombre AS cuadrilla_nombre
       FROM lineas_reporte lr
       LEFT JOIN cuadrillas c ON c.id = lr.cuadrilla_id
       WHERE lr.reporte_id = ?
       ORDER BY lr.id ASC`,
      [reporteId]
    );

    return res.json({ items: rows });
  } catch (err) {
    console.error("Error listando lineas:", err);
    return res.status(500).json({ error: "Error interno al listar lineas" });
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
         r.creado_por_nombre
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
    const [lineas] = await pool.query(
      `
      SELECT
        lr.trabajador_codigo,
        lr.trabajador_nombre,
        lr.hora_inicio,
        lr.hora_fin,
        lr.horas,
        COALESCE(lr.area_nombre, a.nombre) AS area_apoyo
      FROM lineas_reporte lr
      LEFT JOIN areas a ON a.id = lr.area_id
      WHERE lr.reporte_id = ?
      ORDER BY lr.id ASC
      `,
      [id]
    );

    // Plantilla (elige según tipo)
    // Por ahora usamos la de APOYO_HORAS (tu diseño de la imagen)
    const templatePath = path.join(__dirname, "../templates/apoyos_horas.html");
    let html = fs.readFileSync(templatePath, "utf8");

    const fechaTxt = String(reporte.fecha).slice(0, 10);

    const filasHtml = lineas
      .map((l, i) => {
        const hIni = l.hora_inicio ? String(l.hora_inicio).slice(0, 5) : "";
        const hFin = l.hora_fin ? String(l.hora_fin).slice(0, 5) : "";
        const horas = l.horas ?? "";
        const codigo = l.trabajador_codigo ?? "";
        const nombre = l.trabajador_nombre ?? "";
        const area = l.area_apoyo ?? "";

        return `
          <tr>
            <td class="c">${i + 1}</td>
            <td class="c">${codigo}</td>
            <td>${nombre}</td>
            <td class="c">${hIni}</td>
            <td class="c">${hFin}</td>
            <td class="c">${horas}</td>
            <td>${area}</td>
          </tr>
        `;
      })
      .join("");

    html = html
      .replaceAll("{{FECHA}}", fechaTxt)
      .replaceAll("{{TURNO}}", reporte.turno || "")
      .replaceAll("{{PLANILLERO}}", reporte.creado_por_nombre || "")
      .replaceAll("{{FILAS}}", filasHtml);

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
      `attachment; filename="reporte_apoyos_${id}.pdf"`
    );
    return res.send(pdfBuffer);
  } catch (err) {
    console.error("Error PDF:", err);
    return res.status(500).json({ error: "Error generando PDF" });
  }
});
/* =======================================
   GET /reportes/:id (cabecera)
======================================= */
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
         r.activo,
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

    const requiereAreaCabecera = tipo_reporte !== "APOYO_HORAS";

    let areaNombre = null;
    let areaIdFinal = null;

    if (requiereAreaCabecera) {
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
      areaNombre = "POR_TRABAJADOR";
      areaIdFinal = null;
    }

    const [result] = await pool.query(
      `INSERT INTO reportes
       (fecha, turno, tipo_reporte, area, area_id, creado_por_user_id, creado_por_nombre, observaciones)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        fecha,
        turnoNormalizado,
        tipo_reporte,
        areaNombre,
        areaIdFinal,
        creado_por_user_id,
        creado_por_nombre,
        observaciones || null,
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
    const reporteId = Number(req.params.id);
    if (!Number.isInteger(reporteId) || reporteId <= 0) {
      return res.status(400).json({ error: "id de reporte inválido" });
    }

    const {
      trabajador_id,
      cuadrilla_id,
      horas,
      hora_inicio,
      hora_fin,
      kilos,
      labores,
      area_id,
    } = req.body;

    if (!trabajador_id) {
      return res.status(400).json({ error: "trabajador_id es obligatorio" });
    }

    const [repRows] = await pool.query(
      "SELECT id, tipo_reporte FROM reportes WHERE id = ? LIMIT 1",
      [reporteId]
    );
    if (!repRows.length)
      return res.status(404).json({ error: "Reporte no encontrado" });
    const tipo = repRows[0].tipo_reporte;

    // trabajador
    const [tRows] = await pool.query(
      "SELECT id, codigo, nombre_completo FROM trabajadores WHERE id = ? AND activo = 1",
      [trabajador_id]
    );
    if (!tRows.length)
      return res.status(400).json({ error: "Trabajador no válido o inactivo" });
    const trabajador = tRows[0];

    // área solo apoyo horas
    let areaNombre = null;
    if (tipo === "APOYO_HORAS") {
      if (!area_id) {
        return res
          .status(400)
          .json({ error: "area_id es obligatorio para APOYO_HORAS" });
      }

      const [aRows] = await pool.query(
        `SELECT id, nombre
         FROM areas
         WHERE id= ?
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

    // calcular horas si llega hora_fin
    let horasValue = horas ?? null;
    let horaFinValue = hora_fin ?? null;

    if (tipo === "APOYO_HORAS") {
      if (horaFinValue) {
        const toMin = (s) => {
          const [h, m] = String(s).split(":");
          return Number(h) * 60 + Number(m);
        };
        const diff = toMin(horaFinValue) - toMin(hora_inicio);
        if (diff <= 0) {
          return res
            .status(400)
            .json({ error: "hora_fin debe ser mayor que hora_inicio" });
        }
        horasValue = diff / 60;
      } else {
        horasValue = null; // pendiente
      }
    }

    // evitar duplicados: si existe pendiente del mismo trabajador => UPDATE
    if (tipo === "APOYO_HORAS") {
      const [pendiente] = await pool.query(
        `SELECT id
         FROM lineas_reporte
         WHERE reporte_id = ?
           AND trabajador_id = ?
           AND hora_fin IS NULL
         ORDER BY id DESC
         LIMIT 1`,
        [reporteId, trabajador_id]
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
            area_id,
            areaNombre,
            hora_inicio ?? null,
            horaFinValue,
            horasValue,
            pendiente[0].id,
          ]
        );

        return res.json({
          message: "Linea actualizada (pendiente existente)",
          linea_id: pendiente[0].id,
        });
      }
    }

    const [result] = await pool.query(
      `INSERT INTO lineas_reporte
       (reporte_id, trabajador_id, cuadrilla_id, area_id, area_nombre,
        trabajador_codigo, trabajador_nombre, horas, hora_inicio, hora_fin, kilos, labores)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        reporteId,
        trabajador.id,
        cuadrilla_id ?? null,
        area_id ?? null,
        areaNombre,
        trabajador.codigo,
        trabajador.nombre_completo,
        horasValue,
        hora_inicio ?? null,
        horaFinValue,
        kilos ?? null,
        labores ?? null,
      ]
    );

    return res
      .status(201)
      .json({ message: "Linea creada", linea_id: result.insertId });
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

    if (Object.prototype.hasOwnProperty.call(req.body, "observaciones")) {
      updates.push("observaciones = ?");
      params.push(observaciones || null);
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
