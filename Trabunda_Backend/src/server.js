require("./config/env");
require("./db");
const app = require("./index");


const PORT = process.env.PORT || 3000;

let server;

const shutdown = (error) => {
  if (error) {
    console.error("❌ Error no controlado:", error);
  }

  if (server && server.listening) {
    server.close(() => {
      console.log("🛑 Servidor cerrado de forma controlada.");
      process.exit(1);
    });
  } else {
    process.exit(1);
  }
};

process.on("unhandledRejection", (reason) => {
  shutdown(reason);
});

process.on("uncaughtException", (error) => {
  shutdown(error);
});
if (process.env.NODE_ENV === 'development') {
    console.log("🛠️  MODO: Desarrollo (Conectado a la DB de PRUEBAS)");
} else if (process.env.NODE_ENV === 'production') {

    console.log("🚀 MODO: Producción (Conectado a la DB REAL)");
}

app.listen(PORT, "0.0.0.0", () => {
  //console.log(`Servidor TRABUNDA escuchando en http:// 192.168.60.102:${PORT}`);
  //console.log(`Servidor TRABUNDA escuchando en http:// 172.16.1.207:${PORT}`);
  const publicUrl = process.env.PUBLIC_URL || `http://0.0.0.0:${PORT}`;
  console.log(`Servidor TRABUNDA escuchando en ${publicUrl}`);
});
module.exports = app;
