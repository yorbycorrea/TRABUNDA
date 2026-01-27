if (process.env.NODE_ENV !== "test") {
  require("dotenv").config();
}

process.env.PORT ||= "3000";

const requiredVars = [
  "PORT",
  "DB_HOST",
  "DB_PORT",
  "DB_USER",
  "DB_PASS",

  
];

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
