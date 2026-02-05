// src/routes/trabajadores.js
const express = require("express");
const router = express.Router();
const { getTrabajadorPorCodigo, getTrabajadorPorDni } = require("../services/trabajadorApi");
const { authMiddleware } = require("../middlewares/auth");
const { pool } = require("../db");

const MAX_LOOKUP_LENGTH = 20;
const CACHE_REFRESH_DAYS = 7;

const respondWriteDisabled = (res) =>
  res
    .status(501)
    .json({ error: "Operación no disponible sin API de trabajadores." });

const logLookup = (payload) => {
  console.info("[trabajadores.lookup]", payload);
};

const normalizeWorkerRow = (row) => ({
  codigo: row?.codigo ?? null,
  dni: row?.dni ?? null,
  nombre: row?.nombre_completo ?? null,
});

const upsertWorkerCache = async (worker) => {
  await pool.query(
    `INSERT INTO trabajadores
      (codigo, dni, nombre_completo, sexo, activo, actualizado_en)
     VALUES (?, ?, ?, ?, 1, NOW())
     ON DUPLICATE KEY UPDATE
      dni = VALUES(dni),
      nombre_completo = VALUES(nombre_completo),
      sexo = VALUES(sexo),
      activo = 1,
      actualizado_en = NOW()`,
    [
      String(worker.codigo ?? "").trim(),
      String(worker.dni ?? "").trim() || null,
      String(worker.nombre ?? "").trim(),
      String(worker.sexo ?? "").trim() || null,
    ]
  );
};

const refreshByDniIfStale = async ({ dni, actualizadoEn }) => {
  if (!dni || !actualizadoEn) return;
  const updatedAt = new Date(actualizadoEn);
  if (Number.isNaN(updatedAt.getTime())) return;

  const ageMs = Date.now() - updatedAt.getTime();
  if (ageMs < CACHE_REFRESH_DAYS * 24 * 60 * 60 * 1000) return;

  try {
    const freshWorker = await getTrabajadorPorDni(dni);
    await upsertWorkerCache(freshWorker);
    logLookup({ q: dni, tipoDetectado: "dni", refresh: "ok", graphqlCalled: true });
  } catch (error) {
    logLookup({
      q: dni,
      tipoDetectado: "dni",
      refresh: "failed",
      graphqlCalled: true,
      error: error?.code || error?.message,
    });
  }
};

// =======================================
// GET/trabajadores/lookup?q=...
// =======================================
router.get("/lookup", authMiddleware, async (req, res) => {
  const q = String(req.query.q || "").trim();
  const length = q.length;

  if (!q) {
    return res.status(400).json({ error: "q es requerido" });
  }

  if (length > MAX_LOOKUP_LENGTH) {
    logLookup({ q, tipoDetectado: "codigo", length, cacheHit: false, graphqlCalled: false, error: "CODIGO_INVALIDO" });
    return res.status(400).json({ error: "CODIGO_INVALIDO" });
  }

  const isDni = /^\d{8}$/.test(q);
  const tipoDetectado = isDni ? "dni" : "codigo";

  try {
    if (!isDni) {
      const [rows] = await pool.query(
        `SELECT codigo, dni, nombre_completo
         FROM trabajadores
         WHERE codigo = ?
         LIMIT 1`,
        [q]
      );

      const cacheHit = rows.length > 0;
      logLookup({ q, tipoDetectado, length, cacheHit, graphqlCalled: false });

      if (!cacheHit) {
        return res.status(404).json({ error: "TRABAJADOR_NO_ENCONTRADO" });
      }

      return res.json({ ok: true, worker: normalizeWorkerRow(rows[0]) });
    }

    const [rows] = await pool.query(
      `SELECT codigo, dni, nombre_completo, actualizado_en
       FROM trabajadores
       WHERE dni = ?
       LIMIT 1`,
      [q]
    );

    const cacheHit = rows.length > 0;
    logLookup({ q, tipoDetectado, length, cacheHit, graphqlCalled: false });

    if (cacheHit) {
      const row = rows[0];
      refreshByDniIfStale({ dni: row.dni, actualizadoEn: row.actualizado_en });
      return res.json({ ok: true, worker: normalizeWorkerRow(row) });
    }

    const worker = await getTrabajadorPorDni(q);
    await upsertWorkerCache(worker);

    logLookup({ q, tipoDetectado, length, cacheHit: false, graphqlCalled: true });

    return res.json({
      ok: true,
      worker: {
        codigo: worker.codigo,
        dni: worker.dni ?? q,
        nombre: worker.nombre,
      },
    });
  } catch (err) {
    const code = err?.code || err?.message;
    const status = code === "TRABAJADOR_NO_ENCONTRADO" ? 404 : 502;
    const error = code === "TRABAJADOR_NO_ENCONTRADO" ? "TRABAJADOR_NO_ENCONTRADO" : "TRABAJADOR_GQL_ERROR";

    logLookup({ q, tipoDetectado, length, cacheHit: false, graphqlCalled: true, error });
    return res.status(status).json({ error });
  }
});

// ===========================================
// GET /trabajadores  → listar todos
// ===========================================
router.get("/", async (req, res) => {
  return res.status(501).json({
    error: "Listado de trabajadores no disponible sin API de trabajadores.",
  });
});

// ===========================================
// POST /trabajadores  → crear un trabajador
// ===========================================
router.post("/", async (req, res) => {
  return respondWriteDisabled(res);
});

// ====================================
// GET /trabajadores/:id -> Se obtiene por id
// ====================================
router.get("/:id", async (req, res) => {
  const { id } = req.params;

  try {
    const result = await getTrabajadorPorCodigo(String(id).trim());

    if (!result) {
      return res.status(404).json({ error: "Trabajador no encontrado" });
    }

    return res.json({
      id: result.codigo ?? null,
      codigo: result.codigo ?? "",
      dni: result.dni ?? "",
      nombre_completo: result.nombre ?? "",
    });
  } catch (err) {
    const status = err?.message === "TRABAJADOR_NO_ENCONTRADO" ? 404 : 502;
    const errorMessage =
      err?.message === "TRABAJADOR_NO_ENCONTRADO"
        ? "Trabajador no encontrado"
        : "Error al obtener trabajador";
    console.error("Error al obtener trabajador: ", err);
    res.status(status).json({ error: errorMessage });
  }
});

router.put("/:id", async (req, res) => {});

router.delete("/:id", async (req, res) => {
  return respondWriteDisabled(res);
});

router.patch("/:id/activar", async (req, res) => {
  return respondWriteDisabled(res);
});

module.exports = router;
