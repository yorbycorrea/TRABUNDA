const express = require("express");
//console.log("INDEX REAL:", __filename);
//require("./config/env");
const { pool } = require("./db");
//const morgan = require('morgan');

//app.use(morgan('dev'))

// 1. IMPORTAR RUTAS
const trabajadoresRoutes = require("./routes/trabajadores");
const reportesRoutes = require("./routes/reportes");
const { getTrabajadorPorCodigo } = require("./services/trabajadorApi");
const areasRutas = require("./routes/areas");
const authRoutes = require("./routes/auth");
const userRoutes = require("./routes/users");
const healthRoutes = require("./routes/health");
const reportesConteoRapidoRoutes = require("./routes/reportes");
//const trabajoAvanceRoutes = require("./routes/trabajo_avance");

// 2. INICIALIZAR APP (Esto debe ir ANTES de cualquier app.use)
const app = express();

// 3. MIDDLEWARES DE CONFIGURACIÓN
app.use(express.json());

// 4. LOG GLOBAL DE PETICIONES
app.use((req, res, next) => {
  if (process.env.NODE_ENV !== "test") {
    const fullUrl = `${req.protocol}://${req.get("host")}${req.originalUrl}`;
    console.log(
      JSON.stringify(
        {
          type: "http_request",
          method: req.method,
          url: fullUrl,
          headers: req.headers,
          body: req.body,
        },
        null,
        2
      )
    );
  }
  next();
});

app.get("/debug/workers-url", (req, res) => {
  res.json({
    WORKERS_API_URL: process.env.WORKERS_API_URL || "NO DEFINIDA",
  });
});

// 5. DEFINIR RUTAS
app.get("/health", (req, res) => {
  res.json({ ok: true, message: "TRABUNDA backend online " });
});

app.get("/debug/test-worker", async (req, res) => {
  if (process.env.NODE_ENV === "production") {
    return res.status(404).json({ error: "Ruta no disponible" });
  }

  const q = String(req.query.q ?? "").trim();
  if (!q) {
    return res.status(400).json({ error: "q es requerido" });
  }

  try {
    const result = await getTrabajadorPorCodigo(q);
    return res.json(result);
  } catch (err) {
    const status = err?.message === "TRABAJADOR_NO_ENCONTRADO" ? 404 : 502;
    const errorMessage =
      err?.message === "TRABAJADOR_NO_ENCONTRADO"
        ? "Trabajador no encontrado"
        : "Error al consultar trabajador";
    console.error("debug test-worker error: ", err);
    return res.status(status).json({ error: errorMessage });
  }
});

app.use("/health", healthRoutes);
app.use("/trabajadores", trabajadoresRoutes);
app.use("/reportes", reportesRoutes);
app.use("/areas", areasRutas);
app.use("/auth", authRoutes);
//console.log("userRoutes:", userRoutes);
app.use("/users", userRoutes);
app.use("/reportes", reportesConteoRapidoRoutes);
//app.use("/reportes/trabajo-avance", trabajoAvanceRoutes);

// 404 temporal con respuesta JSON para diagnóstico
app.use((req, res) => {
  if (process.env.NODE_ENV !== "test") {
    console.log(
      JSON.stringify(
        {
          type: "http_404",
          method: req.method,
          url: `${req.protocol}://${req.get("host")}${req.originalUrl}`,
        },
        null,
        2
      )
    );
  }
  res.status(404).json({ error: "Ruta no encontrada", method: req.method, url: req.originalUrl });
});

// 6. MANEJO DE ERRORES Y PUERTO
//const PORT = process.env.PORT || 3000;
const { errorHandler } = require("./middlewares/errorHandler");
app.use(errorHandler);

//app.listen(PORT, "0.0.0.0", () => {
//console.log(`Servidor TRABUNDA escuchando en http:// 172.16.1.207:${PORT}`);
//console.log(`Servidor TRABUNDA escuchando en http:// 192.168.60.102:${PORT}`);
//});

module.exports = app;
