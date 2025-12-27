const express = require("express");
require("dotenv").config();
const { pool } = require("./db");

// constantes de rutas
const trabajadoresRoutes = require("./routes/trabajadores");
const reportesRoutes = require("./routes/reportes");
const areasRutas = require("./routes/areas");
const authRoutes = require("./routes/auth");
//const userRoutes = require("./routes/user");
const app = express();
const PORT = process.env.PORT || 3000;
const {errorHandler} = require("./middlewares/errorHandler")

app.use(express.json()); // para leer JSON en requests

// Endpoint simple para ver que el backend está vivo
app.get("/health", (req, res) => {
  res.json({ ok: true, message: "TRABUNDA backend online ✅" });
});

//rutas
app.use("/trabajadores", trabajadoresRoutes);
app.use("/reportes", reportesRoutes);
app.use("/areas", areasRutas);
app.use("/auth", authRoutes);
//app.use("/user", userRoutes);
app.use(errorHandler)
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Servidor TRABUNDA escuchando en http://172.16.1.207:${PORT}`);
});
