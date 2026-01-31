const express = require("express");

const { getTrabajadorPorCodigo } = require("../services/trabajadorApi");

const router = express.Router();

router.get("/workers", async (req, res) => {
  const fallbackCodigo = "000000";
  const codigo = process.env.WORKERS_HEALTHCHECK_CODIGO ?? fallbackCodigo;

  try {
    await getTrabajadorPorCodigo(codigo);
    res.json({ ok: true });
  } catch (error) {
    console.error("WORKERS_HEALTHCHECK_ERROR", error);
    res.status(500).json({ ok: false, error: error.message });
  }
});

module.exports = router;
