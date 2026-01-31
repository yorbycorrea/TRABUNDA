const fetch = global.fetch;

if (!fetch) {
  throw new Error("FETCH_NO_DISPONIBLE");
}

const WORKERS_API_URL =
  process.env.WORKERS_API_URL || "http://172.16.1.207:4806/graphql";
const GET_WORKER_QUERY = `mutation GetWorker($codigo:String!){ getWorker(codigo:$codigo){ ok worker{ id nombres apellidos dni } errors } }`;

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
    cache: "no-store",
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
  const getWorkerResponse = payload?.data?.getWorker;
  const worker = getWorkerResponse?.worker;
  const ok = getWorkerResponse?.ok;
  const errors = getWorkerResponse?.errors;

  if (!ok || (Array.isArray(errors) && errors.length) || !worker) {
    throw buildError("TRABAJADOR_NO_ENCONTRADO", "TRABAJADOR_NO_ENCONTRADO");
  }
  const nombreCompleto = buildNombreCompleto(worker);

  return {
    id: worker.id ?? null,
    codigo: worker.id ?? codigoTrim,
    nombres: worker.nombres ?? "",
    apellidos: worker.apellidos ?? "",
    nombre_completo: nombreCompleto,
    nombre: nombreCompleto,
  };
};

module.exports = {
  getTrabajadorPorCodigo,
};
