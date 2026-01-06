const express = require("express");
const router = express.Router();

const { pool } = require("../db");
const { authMiddleware } = require("../middlewares/auth");

/* ===============================================
   GET /users/pickers?roles=PLANILLERO,SANEAMIENTO
   Solo ADMINISTRADOR
=============================================== */
router.get("/pickers", authMiddleware, async (req, res) => {
  try {
    console.log("REQ.USER:", req.user);

    const role =
      Array.isArray(req.user.roles) && req.user.roles.length > 0
        ? req.user.roles[0]
        : undefined;

    console.log("ROLE:", role);

    if (role !== "ADMINISTRADOR") {
      return res.status(403).json({ error: "Solo administrador" });
    }

    const rolesParam = (req.query.roles || "PLANILLERO,SANEAMIENTO").toString();
    const roles = rolesParam
      .split(",")
      .map((r) => r.trim())
      .filter(Boolean);

    const [rows] = await pool.query(
      `
      SELECT
        u.id,
        u.nombre,
        r.codigo AS role
      FROM users u
      INNER JOIN user_roles ur ON ur.user_id = u.id
      INNER JOIN roles r ON r.id = ur.role_id
      WHERE r.codigo IN (?)
      ORDER BY u.nombre ASC
      `,
      [roles]
    );

    return res.json(rows);
  } catch (err) {
    console.error("Error listando users pickers:", err);
    return res.status(500).json({ error: "Error interno listando usuarios" });
  }
});

module.exports = router;
