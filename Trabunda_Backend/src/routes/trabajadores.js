// src/routes/trabajadores.js
const express = require("express");
const router = express.Router();
//const { getTrabajadorPorCodigo, getTrabajadorPorDni } = require("../services/trabajadorApi");
const { getTrabajadorPorCodigo } = require("../services/trabajadorApi");
const { authMiddleware } = require("../middlewares/auth");
const { pool } = require("../db");

const { resolveTrabajadorLookup } = require("../services/trabajadorLookup");

const respondWriteDisabled = (res) =>
  res
    .status(501)
    .json({ error: "Operación no disponible sin API de trabajadores." });

const logLookup = (payload) => {
  console.info("[trabajadores.lookup]", payload);
};


// =======================================
// GET/trabajadores/lookup?q=...
// =======================================
router.get("/lookup", authMiddleware, async (req, res) => {
   const q = req.query.q;

  try {
    
    const { worker } = await resolveTrabajadorLookup({ q, pool, logLookup });
    return res.json({ ok: true, worker });
  } catch (err) {
    const code = err?.code || err?.message;
    const qResolved = String(q ?? "").trim();
    const status = code === "Q_REQUERIDO" || code === "CODIGO_INVALIDO"
      ? 400
      : code === "TRABAJADOR_NO_ENCONTRADO"
        ? 404
        : 502;
    const error = code === "Q_REQUERIDO"
      ? "q es requerido"
      : code === "CODIGO_INVALIDO"
        ? "CODIGO_INVALIDO"
        : code === "TRABAJADOR_NO_ENCONTRADO"
          ? "TRABAJADOR_NO_ENCONTRADO"
          : "TRABAJADOR_GQL_ERROR";

    logLookup({ q: qResolved, tipoDetectado: err?.tipoDetectado || "codigo", length: err?.length || qResolved.length, cacheHit: false, graphqlCalled: true, error });
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
