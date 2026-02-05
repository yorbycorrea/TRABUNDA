const path = require("path");
const fs = require("fs");

if (process.env.NODE_ENV !== "test") {
   const envPath = process.env.ENV_FILE || path.resolve(process.cwd(), ".env");
  const result = require("dotenv").config({ path: envPath });

  if (result.error && process.env.NODE_ENV !== "production") {
    console.warn(`[env] No se pudo cargar ${envPath}:`, result.error.message);
  }

  if (process.env.ENV_DEBUG === "true") {
    console.log(
      `[env] archivo cargado: ${envPath} (exists=${fs.existsSync(envPath)})`
    );
  }
}

process.env.PORT ||= "3000";

const requiredVars = ["PORT", "DB_HOST", "DB_PORT", "DB_USER", "DB_PASS", "JWT_SECRET"];

const envDbVar =
  process.env.NODE_ENV === "production"
    ? "DB_NAME_PROD"
    : process.env.NODE_ENV === "test"
      ? "DB_NAME_TEST"
      : "DB_NAME_DEV";

const missingVars = requiredVars.filter((key) => !process.env[key]);

if (!process.env.DB_NAME && !process.env[envDbVar]) {
  missingVars.push(`${envDbVar} o DB_NAME`);
}

if (missingVars.length > 0) {
  throw new Error(
    `Faltan variables de entorno requeridas: ${missingVars.join(", ")}`
  );
}
