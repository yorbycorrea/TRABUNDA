if (process.env.NODE_ENV !== "test") {
  require("dotenv").config();
}

const requiredVars = [
  "PORT",
  "DB_HOST",
  "DB_PORT",
  "DB_USER",
  "DB_PASS",
  // Validamos la variable según el entorno actual
  process.env.NODE_ENV === "production" ? "DB_NAME_PROD" : 
  process.env.NODE_ENV === "test" ? "DB_NAME_TEST" : "DB_NAME_DEV"
  
];

const missingVars = requiredVars.filter((key) => !process.env[key]);

if (missingVars.length > 0) {
  throw new Error(
    `Faltan variables de entorno requeridas: ${missingVars.join(", ")}`
  );
}
