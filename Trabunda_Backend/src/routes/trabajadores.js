// src/routes/trabajadores.js
console.log("trabajadores,js cargado desde", __filename)
const express = require("express");
const router = express.Router();
const { getTrabajadorPorCodigo } = require("../services/trabajadores");
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
    if(!qRaw) return res.status(400).json({error: "q es requerido"});
        // quita espacios y saltos de linea
    const q = qRaw.replace(/\s+/g, "");

    
    const result = await getTrabajadorPorCodigo(q);

   if (result?.error) {
    return res.status(result.status || 502).json({error: result.error});
   }

    if (!result) {
      return res.status(404).json({error: "Trabajador no encontrado"});
    }

    const t = rows[0];
    return res.json({
      id: result.id ?? null,
      codigo: result.codigo ?? "",
      dni: result.dni ?? "",
      nombre_completo: result.nombre_completo ?? "",
    });


  } catch (err) {
    console.error("lookup trabajador error: ", err);
    return res.status(500).json({error: "Error interno de lookup"});
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

    if (result?.error) {
      return res.status(result.status || 502).json({ error: result.error });
    }

    if (!result) {
      return res.status(404).json({ error: "Trabajador no encontrado" });
    }

     return res.json({
      id: result.id ?? null,
      codigo: result.codigo ?? "",
      dni: result.dni ?? "",
      nombre_completo: result.nombre_completo ?? "",
    });
  } catch (err) {
    console.error("Error al obtener trabajador: ", err);
    res.status(500).json({ error: "Error al obtener trabajador" });
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
