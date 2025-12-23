const express = require("express");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const { pool } = require("../db");
const { authMiddleware, requireRole } = require("../middlewares/auth");
const crypto = require("crypto");
const { error } = require("console");
const { asyncHandler } = require("../middlewares/asyncHandler");

const router = express.Router();

const generateRefreshToken = () => crypto.randomBytes(48).toString("base64url");
const hashRefreshToken = (token) =>
  crypto.createHash("sha256").update(token).digest("hex");
const getRefreshExpiryDate = () => {
  const days = Number(process.env.REFRESH_TOKEN_EXPIRES_DAYS || 30);
  return new Date(Date.now() + days * 24 * 60 * 60 * 1000);
};

// por que no se peude subir
// =============================================
// POST para crear usuario siendo admin
// body : {username, password, nombre, roles}
// =============================================
router.post(
  "/register",
  authMiddleware,
  requireRole("ADMIN"),
  asyncHandler(async (req, res) => {
    const { username, password, nombre, roles } = req.body;

    if (!username || !password || !nombre) {
      return res.status(400).json({ error: "Faltan campos obligatorios" });
    }

    const rolesFinal =
      Array.isArray(roles) && roles.length > 0 ? roles : ["PLANILLERO"];

    // Iniciamos una conexión para la transacción
    const connection = await pool.getConnection();
    try {
      await connection.beginTransaction();

      // 1) Verificar username
      const [existe] = await connection.query(
        "SELECT id FROM users WHERE username = ? LIMIT 1",
        [username]
      );
      if (existe.length > 0) {
        await connection.release();
        return res.status(400).json({ error: "El username ya existe" });
      }

      // 2) Hashear
      const password_hash = await bcrypt.hash(password, 10);

      // 3) Crear usuario
      const [result] = await connection.query(
        "INSERT INTO users(username, password_hash, nombre) VALUES (?,?,?)",
        [username, password_hash, nombre]
      );
      const userId = result.insertId;

      // 4) Buscar IDs de roles
      const [rowsRoles] = await connection.query(
        `SELECT id FROM roles WHERE codigo IN (?)`,
        [rolesFinal]
      );

      if (rowsRoles.length !== rolesFinal.length) {
        throw new Error("Uno o más roles enviados no son válidos");
      }

      // 5) Insertar todos los roles en una sola consulta
      const roleValues = rowsRoles.map((r) => [userId, r.id]);
      await connection.query(
        "INSERT INTO user_roles (user_id, role_id) VALUES ?",
        [roleValues]
      );

      // Si todo salió bien, confirmamos los cambios
      await connection.commit();

      res.json({
        message: "Usuario creado exitosamente",
        user_id: userId,
        roles: rolesFinal,
      });
    } catch (error) {
      // Si algo falla, deshacemos todo (no se crea el usuario ni los roles)
      await connection.rollback();
      res
        .status(500)
        .json({ error: error.message || "Error al registrar usuario" });
    } finally {
      connection.release(); // Liberar la conexión siempre
    }
  })
);

// =================================================
// POST /auth/login
// =================================================
router.post(
  "/login",
  asyncHandler(async (req, res) => {
    const { username, password } = req.body;

    if (!username || !password) {
      return res
        .status(400)
        .json({ error: "Faltan campos: username, password" });
    }

    // 1. Buscar usuario
    const [users] = await pool.query(
      "SELECT id, username, password_hash, nombre, activo FROM users WHERE username = ? LIMIT 1",
      [username]
    );

    if (users.length === 0) {
      return res.status(401).json({ error: "Credenciales inválidas" });
    }

    const user = users[0];

    // 2. Verificar si está activo
    if (user.activo !== 1) {
      return res.status(403).json({ error: "Usuario desactivado" });
    }

    // 3. Comparar password
    const ok = await bcrypt.compare(password, user.password_hash);
    if (!ok) {
      return res.status(401).json({ error: "Credenciales inválidas" });
    }

    // 4. Obtener roles
    const [roles] = await pool.query(
      `SELECT r.codigo FROM user_roles ur 
     JOIN roles r ON r.id = ur.role_id 
     WHERE ur.user_id = ?`,
      [user.id]
    );
    const roleCodes = roles.map((r) => r.codigo);

    // 5. Firmar Access Token
    const token = jwt.sign(
      { sub: user.id, username: user.username, roles: roleCodes },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN || "12h" }
    );

    // 6. Manejo de Refresh Token
    const refreshToken = generateRefreshToken();
    const refreshTokenHash = hashRefreshToken(refreshToken);
    const refreshExpiresAt = getRefreshExpiryDate();

    await pool.query(
      "INSERT INTO refresh_tokens (user_id, token_hash, expires_at) VALUES (?,?,?)",
      [user.id, refreshTokenHash, refreshExpiresAt]
    );

    return res.json({
      message: "LOGIN OK",
      token,
      refreshToken, // Corregido de 'refresToken'
      user: {
        id: user.id,
        username: user.username,
        nombre: user.nombre,
        roles: roleCodes,
      },
    });
  })
);

//================================================
// GET /auth/me
// ==============================================

router.get("/me", authMiddleware, async (req, res) => {
  try {
    const [users] = await pool.query(
      "SELECT id, username, nombre FROM users WHERE id = ? LIMIT 1",
      [req.user.id]
    );

    if (users.length === 0) {
      return res.status(404).json({ error: "Usuario no encontrado" });
    }

    const user = users[0];
    const [roles] = await pool.query(
      "SELECT r.codigo FROM user_roles ur JOIN roles r ON r.id = ur.role_id WHERE ur.user_id = ?",
      [user.id]
    );
    const roleCodes = roles.map((r) => r.codigo);

    return res.json({
      user: {
        id: user.id,
        username: user.username,
        nombre: user.nombre,
        roles: roleCodes,
      },
    });
  } catch (err) {
    console.error("Error al obtener usuario", err);
    return res.status(500).json({ error: "Error obteniendo usuario" });
  }
});

// ==============================================
// POST /auth/refresh
// body : {refreshtoken}
// ==============================================

router.post("/refresh", async (req, res) => {
  const { refreshToken } = req.body;

  if (!refreshToken) {
    return res.status(400).json({ error: "Falta refreshToken" });
  }

  try {
    const refreshTokenHash = hashRefreshToken(refreshToken);
    const [rows] = await pool.query(
      `SELECT rt.id, rt.user_id, rt.expires_at, u.username, u.nombre, u.activo
      FROM refresh_tokens rt
      JOIN users u ON u.id = rt.user_id
      WHERE rt.token_hash = ? AND rt.revoked_at IS NULL
      LIMIT 1`,
      [refreshTokenHash]
    );

    if (rows.length === 0) {
      return res.status(401).json({ error: "Refresh token invalido" });
    }
    const refreshRow = rows[0];
    if (refreshRow.activo !== 1) {
      return res.status(403).json({ error: "Usuario desactivado" });
    }

    const expires_At = new Date(refreshRow.expires_at);
    if (Number.isNaN(expires_At.getTime()) || expires_At <= new Date()) {
      return res.status(401).json({ error: "Refresh token expirado" });
    }

    const [roles] = await pool.query(
      `SELECT r.codigo
      FROM user_roles ur
      JOIN roles r ON r.id = ur.role_id
      WHERE ur.user_id = ?`,
      [refreshRow.user_id]
    );

    const roleCodes = roles.map((r) => r.codigo);

    const token = jwt.sign(
      {
        sub: refreshRow.user_id,
        username: refreshRow.username,
        roles: roleCodes,
      },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN || "12h" }
    );
    await pool.query(
      "UPDATE refresh_tokens SET last_used_at = NOW() WHERE id = ?",
      [refreshRow.id]
    );
    return res.json({ token });
  } catch (err) {
    console.error("REFRESH ERROR: ", err);
    return res.status(500).json({ error: "Error en refresh" });
  }
});

module.exports = router;
