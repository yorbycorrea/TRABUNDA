// src/routes/trabajadores.js
console.log("trabajadores,js cargado desde", __filename)
const express = require("express");
const router = express.Router();
const { getTrabajadorPorCodigo } = require("../services/trabajadorApi");
const { authMiddleware } = require("../middlewares/auth");

const respondWriteDisabled = (res) =>
  res
    .status(501)
    .json({ error: "Operación no disponible sin API de trabajadores." });

// =======================================
// GET/trabajadores/lookup?q=...
// =======================================

router.get("/lookup",  authMiddleware, async(req, res) => {
  try {
    const qRaw = String(req.query.q ?? "").trim();
    const digits = qRaw.replace(/\D+/g, "");
    const codigo =
      digits.length === 8 ? digits : digits.length > 0 ? digits : qRaw;
    if (!codigo) return res.status(400).json({error: "q es requerido"});

    const result = await getTrabajadorPorCodigo(codigo);

    if (
      !result
      || result.ok === false
      || result === "no encontrado"
      || result?.message === "no encontrado"
    ) {
      return res.status(404).json({error: "Trabajador no encontrado"});
    }




    
    return res.json({
      ok: true,
      worker: {
        codigo: result.codigo,
        nombre: result.nombre,
      },
    });


  } catch (err) {
    const status = err?.message === "TRABAJADOR_NO_ENCONTRADO" ? 404 : 502;
    const errorMessage =
      err?.message === "TRABAJADOR_NO_ENCONTRADO"
        ? "Trabajador no encontrado"
        : "Error al consultar trabajador";
    console.error("lookup trabajador error: ", err);
    return res.status(status).json({error: errorMessage});
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
      dni: "",
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

// ================================================
// PUT /trabajadores/:id -> actualizar campos
// ================================================

router.put("/:id", async (req, res) => {
  
});

// ============================================
// DELETE /trabajadores/:id  -> dar de baja o eliminar
// ============================================

router.delete("/:id", async (req, res) => {
  return respondWriteDisabled(res);
});

//================================================
// PATCH /trabajadores/:id/activar -> activar
// ===============================================

router.patch("/:id/activar", async (req, res) => {
   return respondWriteDisabled(res);
});




// exportar SOLO el router
module.exports = router;
