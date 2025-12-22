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


// ====================================
// GET /trabajadores/:id -> Se obtiene por id
// ====================================

router.get("/id", async(req, res) => {
  const {id} = req.params;

  try {
    const [ rows ] = await pool.query("SELECT id, codigo, nombre_completo, dni, sexo, activo FROM trabajadores WHERE id = ?", [id]);
    if (rows.length === 0){
      return res.status(404).json({error: "Trabajador no encontrado"});
    }

    res.json(rows[0]);
  }catch(err){
    console.error("Error al obtener trabajador: ", err);
    res.status(500).json({error: "Error al obtener trabajador"});
  }

});

// ================================================
// PUT /trabajadores/:id -> actualizar campos 
// ================================================


router.put("/:id", async (req, res) => {
  const {id} = req.params;
  const {nombre_completo, dni, sexo, activo} = req.body;

  const fields = [];
  const values = [];

  if (nombre_completo != undefined){
    fields.push("nombre completo = ?");
    values.push(nombre_completo);

  }

  if (dni != undefined){
    fields.push("dni = ?");
    values.push(dni);
  }

  if(sexo != undefined){
    fields.push("sexo = ?");
    values.push(sexo);
  }

  if(activo != undefined){
    fields.push("activo = ?");
    values.push(activo);
  }
  if (fields.length === 0){
    return res
      .status(400)
      .json({error: "No hay campos para actualizar"});
  }

  try {
    const [exists ] = await pool.query(
      "SELECT id FROM trabajadores  WHERE id = ?", [id]
    );

    if (exists.length === 0){
      return res.status(404).json({error: "Trabajador no encontrado"});

    }

    const query = `UPDATE trabajadores SET ${fields.join(", ")} WHERE id = ? `;
    values.push(id);

    await pool.query(query, values);

    res.json({message: "Trabajador actualizado correctamente"});


  } catch(err){
    console.error("Error al actualizar trabajador:", err);
    res.status(500).json({error: "Error al actualizar trabajador"});
  }
});

// ============================================
// DELETE /trabajadores/:id  -> dar de baja o eliminar
// ============================================

router.delete("/id", async(req, res) => {
  const{id} = req.params;

  try {
    const [exists] = await pool.query("SELECT id FROM trabajadores WHERE id = ?", [id]);

    if(exists.length === 0){
      return res.status(404).json({error: "Trabajador no encontrado"});
    }

    await pool.query("UPDATE trabajadores SET activo = 0 WHERE id = ?", [id]);

    res.json({message: "Trabajador dado de baja correctamente "});


  }catch(err){
    console.error("Error al dar de bajar al trabajador", err);
    res.status(500).json({error: "Error al dar de bajar al trabajador"});
  }

  

});

//================================================
// PATCH /trabajadores/:id/activar -> activar
// ===============================================

router.patch("/:id/activar", async(req, res) =>{
  const {id} = req.params;

  try {

    const [exists] = await pool.query(
      "SELECT id FROM trabajadores WHERE id = ?", [id]
    );

    if (exists.length === 0){
      return res.status(404).json({error: "Trabajador no encontrado"});

    }

    await pool.query("UPDATE trabajadores SET activo = 1 WHERE id = ?", [id]),

    res.json({message: "Trabajador activo correctamente "});


  }catch(err){
    console.error("Error al activar trabajador" , err);
    res.status(500).json({error: "Error al activar trabajador"});
  }
})




// exportar SOLO el router
module.exports = router;
