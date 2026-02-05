const { getTrabajadorPorDni } = require("./trabajadorApi");

const MAX_LOOKUP_LENGTH = 20;
const CACHE_REFRESH_DAYS = 7;

const buildLookupError = (message, code, extra = {}) => {
  const error = new Error(message);
  error.code = code;
  Object.assign(error, extra);
  return error;
};

const normalizeWorkerRow = (row) => ({
  codigo: row?.codigo ?? null,
  dni: row?.dni ?? null,
  nombre: row?.nombre_completo ?? null,
});

const detectWorkerQueryType = (rawInput) => {
  const q = String(rawInput ?? "").trim();
  const isNumeric = /^\d+$/.test(q);

  let tipoDetectado = "codigo";
  if (isNumeric && q.length === 8) {
    tipoDetectado = "dni";
  } else if (q.length <= 5 || /^0/.test(q)) {
    tipoDetectado = "codigo";
  }

  return {
    q,
    length: q.length,
    tipoDetectado,
    codigoNormalizado: tipoDetectado === "codigo" ? q.padStart(5, "0") : null,
    dniNormalizado: tipoDetectado === "dni" ? q : null,
  };
};

const upsertWorkerCache = async (pool, worker) => {
  await pool.query(
    `INSERT INTO trabajadores
      (codigo, dni, nombre_completo, sexo, activo, actualizado_en)
     VALUES (?, ?, ?, ?, 1, NOW())
     ON DUPLICATE KEY UPDATE
      dni = VALUES(dni),
      nombre_completo = VALUES(nombre_completo),
      sexo = VALUES(sexo),
      activo = 1,
      actualizado_en = NOW()`,
    [
      String(worker.codigo ?? "").trim(),
      String(worker.dni ?? "").trim() || null,
      String(worker.nombre ?? "").trim(),
      String(worker.sexo ?? "").trim() || null,
    ]
  );
};

const refreshByDniIfStale = async ({ pool, dni, actualizadoEn, logLookup = () => {} }) => {
  if (!dni || !actualizadoEn) return;
  const updatedAt = new Date(actualizadoEn);
  if (Number.isNaN(updatedAt.getTime())) return;

  const ageMs = Date.now() - updatedAt.getTime();
  if (ageMs < CACHE_REFRESH_DAYS * 24 * 60 * 60 * 1000) return;

  try {
    const freshWorker = await getTrabajadorPorDni(dni);
    await upsertWorkerCache(pool, freshWorker);
    logLookup({ q: dni, tipoDetectado: "dni", refresh: "ok", graphqlCalled: true });
  } catch (error) {
    logLookup({
      q: dni,
      tipoDetectado: "dni",
      refresh: "failed",
      graphqlCalled: true,
      error: error?.code || error?.message,
    });
  }
};

const resolveTrabajadorLookup = async ({ q, pool, logLookup = () => {} }) => {
  const detected = detectWorkerQueryType(q);

  if (!detected.q) {
    throw buildLookupError("q es requerido", "Q_REQUERIDO", detected);
  }

  if (detected.length > MAX_LOOKUP_LENGTH) {
    throw buildLookupError("CODIGO_INVALIDO", "CODIGO_INVALIDO", detected);
  }

  if (detected.tipoDetectado === "codigo") {
    const [rows] = await pool.query(
      `SELECT TRIM(codigo) AS codigo, dni, nombre_completo
       FROM trabajadores
       WHERE TRIM(codigo) = ?
       LIMIT 1`,
      [detected.codigoNormalizado]
    );

    const cacheHit = rows.length > 0;
    logLookup({
      q: detected.q,
      tipoDetectado: detected.tipoDetectado,
      length: detected.length,
      cacheHit,
      graphqlCalled: false,
    });

    if (!cacheHit) {
      throw buildLookupError(
        "TRABAJADOR_NO_ENCONTRADO",
        "TRABAJADOR_NO_ENCONTRADO",
        detected
      );
    }

    return {
      ...detected,
      worker: normalizeWorkerRow(rows[0]),
      source: "cache",
    };
  }

  const [rows] = await pool.query(
    `SELECT TRIM(codigo) AS codigo, dni, nombre_completo, actualizado_en
     FROM trabajadores
     WHERE dni = ?
     LIMIT 1`,
    [detected.dniNormalizado]
  );

  const cacheHit = rows.length > 0;
  logLookup({
    q: detected.q,
    tipoDetectado: detected.tipoDetectado,
    length: detected.length,
    cacheHit,
    graphqlCalled: false,
  });

  if (cacheHit) {
    const row = rows[0];
    refreshByDniIfStale({ pool, dni: row.dni, actualizadoEn: row.actualizado_en, logLookup });
    return {
      ...detected,
      worker: normalizeWorkerRow(row),
      source: "cache",
    };
  }

  try {
    const worker = await getTrabajadorPorDni(detected.dniNormalizado);
    await upsertWorkerCache(pool, worker);

    logLookup({
      q: detected.q,
      tipoDetectado: detected.tipoDetectado,
      length: detected.length,
      cacheHit: false,
      graphqlCalled: true,
    });

    return {
      ...detected,
      worker: {
        codigo: worker.codigo,
        dni: worker.dni ?? detected.dniNormalizado,
        nombre: worker.nombre,
      },
      source: "graphql",
    };
  } catch (error) {
    const code = error?.code || error?.message;
    if (code === "TRABAJADOR_NO_ENCONTRADO") {
      throw buildLookupError(
        "TRABAJADOR_NO_ENCONTRADO",
        "TRABAJADOR_NO_ENCONTRADO",
        detected
      );
    }

    throw buildLookupError("TRABAJADOR_GQL_ERROR", "TRABAJADOR_GQL_ERROR", detected);
  }
};

module.exports = {
  MAX_LOOKUP_LENGTH,
  detectWorkerQueryType,
  resolveTrabajadorLookup,
};
