// src/routes/reportes.js
const express = require("express");
const router = express.Router();
const { pool } = require("../db");
const { authMiddleware } = require("../middlewares/auth");
const PDFDocument = require("pdfkit");
//const { width } = require("pdfkit/js/page");

function esTipoReporteValido(tipo) {
  return [
    "SANEAMIENTO",
    "APOYO_HORAS",
    "TRABAJO_AVANCE",
    "CONTEO_RAPIDO",
  ].includes(tipo);
}

function esTurnoValido(turno) {
  return ["Noche", "Dia"].includes(turno);
}

function nombreTipoReporte(tipo) {
  switch (tipo) {
    case "SANEAMIENTO":
      return "Saneamiento";
    case "APOYOS_HORAS":
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
  if (valor === null || valor === undefined || valor === "") {
    return "-";
  }
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

  // Header
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

  // Rows
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

    const creado_por_user_id = req.user.id;

    // 1) Validar campos obligatorios (para TODOS)
    if (!fecha || !turno || !tipo_reporte) {
      return res.status(400).json({
        error: "Faltan campos obligatorios: fecha, turno, tipo_reporte",
      });
    }

    // ✅ Normalizar turno (tu app manda "Dia", tu BD puede tener "Día")
    const turnoNormalizado =
      turno === "Dia" ? "Día" : turno === "DIA" ? "Día" : turno;

    if (!esTurnoValido(turnoNormalizado)) {
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

    // ✅ 3) Reglas por tipo:
    // - APOYO_HORAS: NO requiere area_id en cabecera (área será por trabajador en lineas_reporte)
    // - Los demás: SÍ requieren area_id
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

      // Validar que el área exista y sea compatible con ese tipo de reporte
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

      areaNombre = areas[0].nombre;
      areaIdFinal = areas[0].id;
    } else {
      // ✅ APOYO_HORAS: como tu columna reportes.area es NOT NULL,
      // guardamos un texto fijo indicando que el área se define por línea.
      areaNombre = "POR_TRABAJADOR";
      areaIdFinal = null;
    }

    // 4) Insertar en reportes
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

// =========================================================
// PUT /reportes/:id para actualizar los campos editables del informe con validacion
// =========================================================

router.put("/:id", authMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    const { fecha, turno, area_id, observaciones } = req.body;

    const [rows] = await pool.query(
      "SELECT id, tipo_reporte FROM reportes WHERE id = ? LIMIT 1",
      [id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: "Reporte no encontrado" });
    }

    const tipoReporte = rows[0].tipo_reporte;
    const updates = [];
    const params = [];

    if (fecha !== undefined) {
      updates.push("fecha = ?");
      params.push(fecha);
    }

    if (turno !== undefined) {
      if (!esTurnoValido(turno)) {
        return res.status(400).json({ error: "turno no valido" });
      }

      updates.push("turno = ?");
      params.push(turno);
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
        WHERE id = ? AND ${flag} = 1 AND activo = 1`,
        [area_id]
      );

      if (areas.length === 0) {
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

    if (updates.length === 0) {
      return res.status(400).json({
        error: "No hay campos editables para actualizar",
      });
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
         r.activo,
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

// ===============================================
// GET /reportes/:id/pdf -> PDF
// ===============================================

router.get("/:id/pdf", authMiddleware, async (req, res) => {
  return res.status(501).json({ error: "PDF aún no implementado" });
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
      activo,
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
    const orderDir = dirs.has(String(dir).toLowerCase())
      ? String(dir).toLowerCase()
      : "desc";

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
         r.activo,
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

// ======================================
// PATCH activar/desactivar reporte
// =======================================

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

// ========================================
// POST /reportes/:id/lineas
// ========================================
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

    // 1) validar confirmar tipo de reporte
    const [repRows] = await pool.query(
      "SELECT id, tipo_reporte FROM reportes WHERE id = ?",
      [reporteId]
    );
    if (repRows.length === 0)
      return res.status(404).json({ error: "Reporte no encontrado" });
    const tipo = repRows[0].tipo_reporte;

    let areaNombre = null;

    if(tipo === "APOYOS_HORAS"){
      if(!area_id){
        return res.status(400).json({
          error: "area_id es obligatorio  para APOYOS_HORAS",
        });
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

      if(!aRows.length){
        return res.status(400).json({
          error: "Area no validad para APOYO_HORAS ",
        });
      }
      areaNombre = aRows[0].nombre;
    }

    // 2) validar trabajador activo
    const [tRows] = await pool.query(
      "SELECT id, codigo, nombre_completo FROM trabajadores WHERE id = ? AND activo = 1",
      [trabajador_id]
    );
    if (tRows.length === 0)
      return res.status(400).json({ error: "Trabajador no válido o inactivo" });
    const trabajador = tRows[0];

    // 3) validaciones por tipo
    const requeridos = {
      SANEAMIENTO: ["hora_inicio", "hora_fin", "labores"],
      APOYO_HORAS: ["hora_inicio"],
      TRABAJO_AVANCE: ["kilos"],
      CONTEO_RAPIDO: [], // tu BD no soporta conteo aquí (decidir luego)
    };
    const campos = requeridos[tipo];
    if (!campos)
      return res.status(400).json({ error: "tipo_reporte no soportado" });

    const map = { horas, hora_inicio, hora_fin, kilos, labores };
    const faltan = campos.filter(
      (k) => map[k] === undefined || map[k] === null || map[k] === ""
    );
    if (faltan.length) {
      return res
        .status(400)
        .json({ error: `Para ${tipo} se requieren: ${campos.join(", ")}` });
    }

    // 4) validar cuadrilla si mandan cuadrilla_id
    if (cuadrilla_id !== undefined && cuadrilla_id !== null) {
      const [cRows] = await pool.query(
        "SELECT id FROM cuadrillas WHERE id = ? AND reporte_id = ?",
        [cuadrilla_id, reporteId]
      );
      if (cRows.length === 0) {
        return res
          .status(400)
          .json({ error: "cuadrilla_id no válida para este reporte" });
      }
    }

    let horasValue = horas ?? null;
let horaFinValue = hora_fin ?? null;

// ✅ si mandan hora_fin, entonces calcula horas si no viene
if (tipo === "APOYO_HORAS") {
  if (horaFinValue && (horasValue === null || horasValue === undefined)) {
    // calcula horas desde hora_inicio y hora_fin (formato HH:MM o HH:MM:SS)
    const toMin = (s) => {
      const [h, m] = String(s).split(":");
      return Number(h) * 60 + Number(m);
    };
    const diff = toMin(horaFinValue) - toMin(hora_inicio);
    horasValue = diff > 0 ? diff / 60 : 0;
  }

  // ✅ si NO hay hora_fin, horas debe ir null (queda incompleto)
  if (!horaFinValue) {
    horasValue = null;
  }
}

    // 5) insertar linea
    const [result] = await pool.query(
      `INSERT INTO lineas_reporte
       (reporte_id, trabajador_id, cuadrilla_id, area_id, area_nombre, trabajador_codigo, trabajador_nombre, horas, hora_inicio, hora_fin, kilos, labores)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        reporteId,
        trabajador.id,
        cuadrilla_id ?? null,
        area_id ??  null,
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

// =======================================
// GET /reportes/:id/detalles
// =======================================
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
         lr.horas,
         lr.hora_inicio,
         lr.hora_fin,
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

// =========================================
// PATCH /reportes/lineas/:lineaId
// =========================================
router.patch("/lineas/:lineaId", authMiddleware, async (req, res) => {
  try {
    const lineaId = Number(req.params.lineaId);
    if (!Number.isInteger(lineaId) || lineaId <= 0) {
      return res.status(400).json({ error: "lineaId inválido" });
    }

    const { cuadrilla_id, horas, hora_inicio, hora_fin, kilos, labores } =
      req.body;

    const updates = [];
    const params = [];

    if (cuadrilla_id !== undefined) {
      updates.push("cuadrilla_id = ?");
      params.push(cuadrilla_id ?? null);
    }
    if (horas !== undefined) {
      updates.push("horas = ?");
      params.push(horas ?? null);
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

    return res.json({ message: "Linea actualizada" });
  } catch (err) {
    console.error("Error actualizando linea:", err);
    return res.status(500).json({ error: "Error interno al actualizar linea" });
  }
});

// =====================================================
// DELETE /reportes/lineas/:lineaId
// ====================================================

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

// =====================================
//======================================

module.exports = router;
