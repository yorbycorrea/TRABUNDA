const express = require("express");
//console.log("INDEX REAL:", __filename);
require("./config/env");
const { pool } = require("./db");

// 1. IMPORTAR RUTAS
const trabajadoresRoutes = require("./routes/trabajadores");
const reportesRoutes = require("./routes/reportes");
const areasRutas = require("./routes/areas");
const authRoutes = require("./routes/auth");
const userRoutes = require("./routes/users");
const reportesConteoRapidoRoutes = require("./routes/reportes");
//const trabajoAvanceRoutes = require("./routes/trabajo_avance");

// 2. INICIALIZAR APP (Esto debe ir ANTES de cualquier app.use)
const app = express();

// 3. MIDDLEWARES DE CONFIGURACIÓN
app.use(express.json());

// 4. LOG DE PETICIONES (Muévelo aquí abajo)
app.use((req, res, next) => {
  if (process.env.NODE_ENV !== "test") {
  console.log(`Petición recibida: ${req.method} ${req.url}`);
}

  next();
});

// 5. DEFINIR RUTAS
app.get("/health", (req, res) => {
  res.json({ ok: true, message: "TRABUNDA backend online ✅" });
});

app.use("/trabajadores", trabajadoresRoutes);
app.use("/reportes", reportesRoutes);
app.use("/areas", areasRutas);
app.use("/auth", authRoutes);
//console.log("userRoutes:", userRoutes);
app.use("/users", userRoutes);
app.use("/reportes", reportesConteoRapidoRoutes);
//app.use("/reportes/trabajo-avance", trabajoAvanceRoutes);

// 6. MANEJO DE ERRORES Y PUERTO
//const PORT = process.env.PORT || 3000;
const { errorHandler } = require("./middlewares/errorHandler");
app.use(errorHandler);

//app.listen(PORT, "0.0.0.0", () => {
//console.log(`Servidor TRABUNDA escuchando en http:// 172.16.1.207:${PORT}`);
//console.log(`Servidor TRABUNDA escuchando en http:// 192.168.60.102:${PORT}`);
//});

module.exports = app;
