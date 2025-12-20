// src/routes/trabajadores.js
const express = require("express");
const router = express.Router();
const { pool } = require("../db");

// ===========================================
// GET /trabajadores  → listar todos
// ===========================================
router.get("/", async (req, res) => {
  try {
    const [rows] = await pool.query(
      "SELECT id, codigo, nombre_completo, dni, sexo, activo FROM trabajadores ORDER BY nombre_completo"
    );
    res.json(rows);
  } catch (err) {
    console.error("Error al listar trabajadores:", err);
    res.status(500).json({ error: "Error al listar trabajadores" });
  }
});

// ===========================================
// POST /trabajadores  → crear un trabajador
// ===========================================
router.post("/", async (req, res) => {
  const { codigo, nombre_completo, dni, sexo } = req.body;

  try {
    // Verificar que el código no exista
    const [existe] = await pool.query(
      "SELECT id FROM trabajadores WHERE codigo = ?",
      [codigo]
    );

    if (existe.length > 0) {
      return res.status(400).json({ error: "El código ya existe" });
    }

    // Insertar trabajador
    const [result] = await pool.query(
      "INSERT INTO trabajadores (codigo, nombre_completo, dni, sexo) VALUES (?, ?, ?, ?)",
      [codigo, nombre_completo, dni, sexo]
    );

    res.json({
      message: "Trabajador registrado correctamente",
      trabajador_id: result.insertId,
    });
  } catch (err) {
    console.error("Error al crear trabajador:", err);
    res.status(500).json({ error: "Error al crear trabajador" });
  }
});

// exportar SOLO el router
module.exports = router;
