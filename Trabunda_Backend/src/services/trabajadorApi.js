const fetch = global.fetch;

if (!fetch) {
  throw new Error("FETCH_NO_DISPONIBLE");
}

const WORKERS_API_URL = process.env.WORKERS_API_URL || process.env.TRABAJADOR_API_URL ||
  'http://trabajadorapi:4806/graphql';
const GET_WORKER_QUERY = `query GetWorker($codigo: String!) {
  getWorker(codigo: $codigo) {
    id
    nombres
    apellidos
  }
}`;

const buildNombreCompleto = (worker) =>
  `${worker.nombres || ""} ${worker.apellidos || ""}`.trim();

const buildError = (message, code) => {
  const error = new Error(message);
  error.code = code;
  return error;
};

const getTrabajadorPorCodigo = async (codigo) => {
   const codigoTrim = String(codigo ?? "").trim();
  if (!codigoTrim) {
    throw buildError("TRABAJADOR_NO_ENCONTRADO", "TRABAJADOR_NO_ENCONTRADO");
  }

  if (!WORKERS_API_URL) {
    throw buildError("WORKERS_API_URL no configurada", "TRABAJADOR_GQL_NO_CONFIG");
  }

  const response = await fetch(WORKERS_API_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      query: GET_WORKER_QUERY,
      variables: { codigo: codigoTrim },
    }),
  });

  if (!response.ok) {
     throw buildError(
      `Error consultando trabajadores (${response.status})`,
      "TRABAJADOR_GQL_ERROR"
    );
  }

  const payload = await response.json();
  if (Array.isArray(payload.errors) && payload.errors.length) {
    const gqlError = payload.errors[0];
    throw buildError(
      gqlError.message || "Error consultando trabajadores",
      gqlError.extensions?.code || "TRABAJADOR_GQL_ERROR"
    );
  }
  const worker = payload?.data?.getWorker;

  if (!worker) {
    throw buildError("TRABAJADOR_NO_ENCONTRADO", "TRABAJADOR_NO_ENCONTRADO");
  }
   const nombreCompleto = buildNombreCompleto(worker);

  return {
    id: worker.id ?? null,
    codigo: codigoTrim,
    nombres: worker.nombres ?? "",
    apellidos: worker.apellidos ?? "",
    nombre_completo: nombreCompleto,
    nombre: nombreCompleto,
  };
};

module.exports = {
  getTrabajadorPorCodigo,
};
