// src/routes/trabajadores.js
console.log("trabajadores,js cargado desde", __filename)
const express = require("express");
const router = express.Router();
const { pool } = require("../db");
const { authMiddleware } = require("../middlewares/auth");



// =======================================
// GET/trabajadores/lookup?q=...
// =======================================

router.get("/lookup",  authMiddleware, async(req, res) => {
  try {
    const qRaw = String(req.query.q ?? "").trim();
    if(!qRaw) return res.status(400).json({error: "q es requerido"});
        // quita espacios y saltos de linea
    const q = qRaw.replace(/\s+/g, "");

    const isNumeric = /^\d+$/.test(q);

    

    let sql = `
      SELECT id, codigo, dni, nombre_completo
      FROM trabajadores 
      WHERE activo = 1
        AND(
        codigo = ?
        OR dni = ?
        OR nombre_completo LIKE?
        )
      LIMIT 1
    
    `;
    const params = [
      q,
      q,
      `%${qRaw}%`,
    ];

  const [who] = await pool.query(`
  SELECT
    DATABASE() AS db,
    @@hostname AS host,
    USER() AS user
`);
  console.log("DB ACTUAL:", who[0]);

    console.log("LOOKUP qRaw", qRaw);
    console.log("LOOKUP q:", q);
    console.log("BD CONFIG;", {
      host: process.env.DB_HOST,
      database: process.env.DB_NAME,
      user: process.env.DB_USER,
    })

    const [rows] = await pool.query(sql, params);

    if (!rows.length) {
      return res.status(404).json({error: "Trabajador no encontrado"});
    }

    const t = rows[0];
    return res.json({
      id: t.id,
      codigo: t.codigo,
      dni: t.dni,
      nombre_completo: t.nombre_completo,
    });


  }catch (err) {
    console.error("lookup trabajador error: ", err);
    return res.status(500).json({error: "Error interno de lookup"});
  }
});
// ===========================================
// GET /trabajadores  → listar todos
// ===========================================
router.get("/", async (req, res) => {
  try {
    const { page = 1, limit = 20, activo, q } = req.query;

    const pageNum = Math.max(parseInt(page, 10) || 1, 1);
    const limitNum = Math.min(Math.max(parseInt(limit, 10) || 20, 1), 200);
    const offset = (pageNum - 1) * limitNum;

    const where = [];
    const params = [];

    if (activo !== undefined) {
      const activoValue =
        activo === "true" ? 1 : activo === "false" ? 0 : Number(activo);
      if (!Number.isNaN(activoValue)) {
        where.push("activo = ? ");
        params.push(activoValue);
      }
    }

    if (q) {
      where.push("(nombre_completo LIKE ? OR dni LIKE ? OR codigo LIKE ?)");
      params.push(`%${q}%`, `%${q}%`, `%${q}%`);
    }

    const whereSql = where.length ? `WHERE ${where.join(" AND ")}` : "";

    const [countRows] = await pool.query(
      `SELECT COUNT(*) AS total FROM trabajadores ${whereSql}`,
      params
    );

    const total = countRows[0]?.total || 0;
    const total_pages = Math.ceil(total / limitNum);

    const [rows] = await pool.query(
      `SELECT id, codigo, nombre_completo, dni, sexo, activo
      FROM trabajadores
      ${whereSql}
      ORDER BY nombre_completo
      LIMIT ? OFFSET ?`,
      [...params, limitNum, offset]
    );

    res.json({
      page: pageNum,
      limit: limitNum,
      total,
      total_pages,
      items: rows,
    });
  } catch (err) {
    console.error("Error al listar trabajadores: ", err);
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

// ====================================
// GET /trabajadores/:id -> Se obtiene por id
// ====================================

router.get("/:id", async (req, res) => {
  const { id } = req.params;

  try {
    const [rows] = await pool.query(
      "SELECT id, codigo, nombre_completo, dni, sexo, activo FROM trabajadores WHERE id = ?",
      [id]
    );
    if (rows.length === 0) {
      return res.status(404).json({ error: "Trabajador no encontrado" });
    }

    res.json(rows[0]);
  } catch (err) {
    console.error("Error al obtener trabajador: ", err);
    res.status(500).json({ error: "Error al obtener trabajador" });
  }
});

// ================================================
// PUT /trabajadores/:id -> actualizar campos
// ================================================

router.put("/:id", async (req, res) => {
  const { id } = req.params;
  const { nombre_completo, dni, sexo, activo } = req.body;

  const fields = [];
  const values = [];

  if (nombre_completo != undefined) {
    fields.push("nombre_completo = ?");
    values.push(nombre_completo);
  }

  if (dni != undefined) {
    fields.push("dni = ?");
    values.push(dni);
  }

  if (sexo != undefined) {
    fields.push("sexo = ?");
    values.push(sexo);
  }

  if (activo != undefined) {
    fields.push("activo = ?");
    values.push(activo);
  }
  if (fields.length === 0) {
    return res.status(400).json({ error: "No hay campos para actualizar" });
  }

  try {
    const [exists] = await pool.query(
      "SELECT id FROM trabajadores  WHERE id = ?",
      [id]
    );

    if (exists.length === 0) {
      return res.status(404).json({ error: "Trabajador no encontrado" });
    }

    const query = `UPDATE trabajadores SET ${fields.join(", ")} WHERE id = ? `;
    values.push(id);

    await pool.query(query, values);

    res.json({ message: "Trabajador actualizado correctamente" });
  } catch (err) {
    console.error("Error al actualizar trabajador:", err);
    res.status(500).json({ error: "Error al actualizar trabajador" });
  }
});

// ============================================
// DELETE /trabajadores/:id  -> dar de baja o eliminar
// ============================================

router.delete("/:id", async (req, res) => {
  const id = Number(req.params.id);

  if (Number.isNaN(id)) {
    return res.status(400).json({ error: "ID inválido" });
  }

  try {
    const [exists] = await pool.query(
      "SELECT id FROM trabajadores WHERE id = ?",
      [id]
    );

    if (exists.length === 0) {
      return res.status(404).json({ error: "Trabajador no encontrado" });
    }

    await pool.query("UPDATE trabajadores SET activo = 0 WHERE id = ?", [id]);

    res.json({ message: "Trabajador dado de baja correctamente " });
  } catch (err) {
    console.error("Error al dar de bajar al trabajador", err);
    res.status(500).json({ error: "Error al dar de bajar al trabajador" });
  }
});

//================================================
// PATCH /trabajadores/:id/activar -> activar
// ===============================================

router.patch("/:id/activar", async (req, res) => {
  const { id } = req.params;

  try {
    const [exists] = await pool.query(
      "SELECT id FROM trabajadores WHERE id = ?",
      [id]
    );

    if (exists.length === 0) {
      return res.status(404).json({ error: "Trabajador no encontrado" });
    }

    

    await pool.query("UPDATE trabajadores SET activo = 1 WHERE id = ?", [id]),
      res.json({ message: "Trabajador activo correctamente " });
  } catch (err) {
    console.error("Error al activar trabajador", err);
    res.status(500).json({ error: "Error al activar trabajador" });
  }
});




// exportar SOLO el router
module.exports = router;
