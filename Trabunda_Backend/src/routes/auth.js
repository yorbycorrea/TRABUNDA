const express= require("express");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const {pool} = require("../db");


const router = express.Router();
// por que no se peude subir
// =============================================
// POST para crear usuario siendo admin
// body : {username, password, nombre, roles}
// =============================================
router.post("/register", async (req, res) => {
  const { username, password, nombre, roles } = req.body;

  if (!username || !password || !nombre) {
    return res.status(400).json({
      error: "Faltan campos: username, password, nombre",
    });
  }

  //Si roles no viene como array, ponemos uno por defecto
  const rolesFinal = Array.isArray(roles) && roles.length > 0 ? roles : ["PLANILLERO"];

  try {
    // 1) Verificar username único
    const [existe] = await pool.query(
      "SELECT id FROM users WHERE username = ? LIMIT 1",
      [username]
    );

    if (existe.length > 0) {
      return res.status(400).json({ error: "El username ya existe" });
    }

    // 2) Hashear password
    const password_hash = await bcrypt.hash(password, 10);

    // 3) Crear usuario
    const [result] = await pool.query(
      "INSERT INTO users(username, password_hash, nombre) VALUES (?,?,?)",
      [username, password_hash, nombre]
    );

    const userId = result.insertId;

    //  4) Buscar roles por codigo 
    const placeholders = rolesFinal.map(() => "?").join(",");
    const [rowsRoles] = await pool.query(
      `SELECT id, codigo FROM roles WHERE codigo IN (${placeholders})`,
      rolesFinal
    );

    if (rowsRoles.length !== rolesFinal.length) {
      return res.status(400).json({ error: "Uno o más roles no existen" });
    }

    // 5) Insertar en user_roles
    for (const r of rowsRoles) {
      await pool.query(
        "INSERT INTO user_roles (user_id, role_id) VALUES (?, ?)",
        [userId, r.id]
      );
    }

    return res.json({
      message: "Usuario creado",
      user_id: userId,
      roles: rolesFinal,
    });
  } catch (err) {
    console.error("REGISTER ERROR:", err);
    return res.status(500).json({ error: "Error creando usuario" });
  }
});

// =================================================
// POST /auth/login
// body : {username, password}
// =================================================

router.post("/login", async(req, res) => {
    const {username, password} = req.body;

    if (!username || !password) {
        return res.status(400).json({error: "Faltan campos: username, password"});


    }

    try{
        // buscar user
        const [users] = await pool.query(
            "SELECT id, username, password_hash, nombre, activo FROM users WHERE username = ? LIMIT 1", [username]
        );

        if (users.length === 0) return res.status(401).json({error: "Credenciales invalidas"});

        const user = users[0];
        
        if(user.activo !==1) return res.status(403).json({error: "Usuario desactivado"});

        // Comparar password

        const ok = await bcrypt.compare(password, user.password_hash);
        if(!ok) return res.status(401).json({error:"Credenciales invalidas"});

        // verificar a que rol pertence y traerlos
        const [roles] = await pool.query(`SELECT r.codigo FROM user_roles ur JOIN roles r ON r.id = ur.role_id WHERE ur.user_id = ?`, [user.id]);

        const roleCodes = roles.map((r) => r.codigo);

        // FIRMAR TOKEN
        const token = jwt.sign(
            {sub: user.id, username: user.username, roles:roleCodes},
            process.env.JWT_SECRET,
            {expiresIn: process.env.JWT_EXPIRES_IN || "12h"}
        );

        return res.json({
            message:"LOGIN OK", 
            token, 
            user: {id: user.id, username: user.username, nombre: user.nombre, roles: roleCodes},
        });

                
    } catch (err){
        console.error(err);
        return res.status(500).json({error: "Error en login"});


    }
})

module.exports = router;
