const mysql = require("mysql2/promise");
require("dotenv").config();

let selectedDatabase;

switch (process.env.NODE_ENV) {
    case 'production':
          selectedDatabase = process.env.DB_NAME_PROD || process.env.DB_NAME;
        console.log("🚀 Conectado a la BD de PRODUCCIÓN");
        break;
    case 'test':
        selectedDatabase = process.env.DB_NAME_TEST || process.env.DB_NAME;
        console.log("🧪 Conectado a la BD de TEST");
        break;
    case 'development':
    default:
        selectedDatabase = process.env.DB_NAME_DEV || process.env.DB_NAME;
        console.log("🛠️ Conectado a la BD de DESARROLLO");
        break;
}

// 2. Validación de seguridad para Test (basada en tu imagen)
if (process.env.NODE_ENV === "test" && !selectedDatabase.includes("test")) {
    throw new Error("SEGURIDAD: Modo TEST activo pero la BD no es de test. Abortando.");
}

console.log(
  `🔧 DB bootstrap -> NODE_ENV: ${process.env.NODE_ENV}, selectedDatabase: ${selectedDatabase}`
);

console.log(process.env.DB_HOST,process.env.DB_USER, process.env.DB_PASS)

// 3. Configuración dinámica del Pool
const pool = mysql.createPool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT || 3306,
  user: process.env.DB_USER,
  password: process.env.DB_PASS,
  // Aquí eliges la BD según el entorno si fuera necesario:
  database: selectedDatabase, 
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
});

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const waitForDb = async (maxAttempts = 7, initialDelayMs = 500) => {
  let delayMs = initialDelayMs;

  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      await pool.query("SELECT 1");
      return;
    } catch (error) {
      if (attempt === maxAttempts) {
        throw error;
      }

      console.warn(
        `⚠️  Intento ${attempt}/${maxAttempts} de conexión a la BD falló. Reintentando en ${delayMs}ms...`
      );
      await sleep(delayMs);
      delayMs *= 2;
    }
  }
};

// Agrega esto justo después de crear el pool
(async () => {
  try {
    await waitForDb();
    const [rows] = await pool.query("SELECT DATABASE() as db");
    console.log("-----------------------------------------");
    console.log(`📡 SERVIDOR ACTIVO EN MODO: ${process.env.NODE_ENV}`);
    console.log(`🗄️  CONECTADO A LA BASE DE DATOS: ${rows[0].db}`);
    console.log("-----------------------------------------");
  } catch (error) {
    console.error("❌ No se pudo conectar a la BD durante el arranque.", error);
  }
})();


module.exports = { pool, selectedDatabase, waitForDb };