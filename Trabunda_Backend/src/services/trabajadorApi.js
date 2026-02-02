const fetch = global.fetch;

if (!fetch) {
  throw new Error("FETCH_NO_DISPONIBLE");
}

const WORKERS_API_URL =
  process.env.WORKERS_API_URL || "http://172.16.1.207:4806/graphql";
const isDni = (q) => /^\d{8}$/.test(String(q).trim());

const GET_WORKER_QUERY = `
mutation GetWorker($codigo:String!){
  getWorker(codigo:$codigo){
    ok
    worker{ id nombres apellidos dni }
    errors { message }
  }
}`;

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

  const response = await fetch(WORKERS_API_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    cache: "no-store",
    body: JSON.stringify({
      query: GET_WORKER_QUERY,
      variables: { codigo: codigoTrim, porDni: isDni(codigoTrim) }
    }),
  });

  let payload;
  try {
    payload = await response.json();
  } catch (error) {
    console.error("Error parseando JSON de trabajadores", {
      status: response.status,
      url: response.url || WORKERS_API_URL,
      error: error?.message,
    });
    throw buildError("TRABAJADOR_GQL_ERROR", "TRABAJADOR_GQL_ERROR");
  }

  const status = response.status;
  const url = response.url || WORKERS_API_URL;
  const payloadErrors = Array.isArray(payload?.errors) ? payload.errors : [];

  if (payloadErrors.length) {
    console.error("Errores GraphQL (nivel raíz)", {
      status,
      url,
      errors: payloadErrors.map((e) => e?.message),
    });
  }

  if (!response.ok) {
    console.error("Respuesta no OK desde trabajadores", {
      status,
      url,
      payload,
    });
    throw buildError("TRABAJADOR_GQL_ERROR", "TRABAJADOR_GQL_ERROR");
  }

  const getWorkerResponse = payload?.data?.getWorker;
  const worker = getWorkerResponse?.worker;
  const ok = getWorkerResponse?.ok;
  const errors = getWorkerResponse?.errors;

  if (!ok || !worker) {
    const msg = Array.isArray(errors) && errors.length
      ? errors.map((e) => e?.message).filter(Boolean).join(", ")
      : null;
    if (msg) console.error("getWorker errors:", msg);

    throw buildError("TRABAJADOR_NO_ENCONTRADO", "TRABAJADOR_NO_ENCONTRADO");
  }

  return {
    codigo: worker.id,
    nombre: `${worker.nombres} ${worker.apellidos}`.trim(),
  };
};

module.exports = { getTrabajadorPorCodigo };
