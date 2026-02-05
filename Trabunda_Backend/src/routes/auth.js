const express = require("express");

const { authMiddleware, requireRole } = require("../middlewares/auth");
const authController = require("../controllers/auth.controller");

const router = express.Router();



// por que no se peude subir
// =============================================
// POST para crear usuario siendo admin
// body : {username, password, nombre, roles}
// =============================================
router.post(
  "/register",
  authMiddleware,
  requireRole("ADMINISTRADOR"),
  authController.register
);

// =================================================
// POST /auth/login
// =================================================
router.post("/login", authController.login)

//================================================
// GET /auth/me
// ==============================================

router.get("/me", authMiddleware, authController.me);

// ==============================================
// POST /auth/refresh
// body : {refreshtoken}
// ==============================================

router.post("/refresh", authController.refresh);

// ==============================================
// POST /auth/logout
// body : { refreshToken }
// ==============================================
router.post("/logout", async (req, res) => {
  const { refreshToken } = req.body;

  if (!refreshToken) {
    return res.status(400).json({ error: "Falta refreshToken" });
  }

  try {
    const refreshTokenHash = hashRefreshToken(refreshToken);

    // Marcamos el token como revocado en la base de datos
    await pool.query(
      "UPDATE refresh_tokens SET revoked_at = NOW() WHERE token_hash = ?",
      [refreshTokenHash]
    );

    return res.json({ message: "Sesión cerrada exitosamente" });
  } catch (err) {
    console.error("LOGOUT ERROR: ", err);
    return res.status(500).json({ error: "Error al cerrar sesión" });
  }
});

module.exports = router;
