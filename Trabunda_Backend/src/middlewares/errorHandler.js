function errorHandler(err, req, res, next) {
  
 if (process.env.NODE_ENV !== "test") {
  console.error("Error:", err);
}


  const status = err.statusCode || err.status || 500;

  // Mensaje base
  if (status >= 500) {
    // 500: prefijo + detalle (err.message)
    const detail = err && err.message ? String(err.message) : "";
    return res.status(500).json({
      error: `Error interno del servidor: ${detail}`.trim(),
    });
  }

  
  const msg = err && err.message ? String(err.message) : "Error";
  return res.status(status).json({ error: msg });
}

module.exports = { errorHandler };
