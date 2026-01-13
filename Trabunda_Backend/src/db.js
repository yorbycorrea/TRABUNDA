// src/db.js
const mysql = require("mysql2/promise");
require("dotenv").config();

if (
  process.env.NODE_ENV === "test" &&
  !String(process.env.DB_NAME).includes("test")
) {
  throw new Error(
    "❌ SEGURIDAD: NODE_ENV=test pero la BD NO es de test. Abortando."
  );
}


const pool = mysql.createPool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  user: process.env.DB_USER,
  password: process.env.DB_PASS,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
});

module.exports = { pool };
