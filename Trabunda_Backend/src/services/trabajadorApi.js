const fetch = global.fetch;

if (!fetch) {
  throw new Error("FETCH_NO_DISPONIBLE");
}

const WORKERS_API_URL =
  process.env.WORKERS_API_URL || "http://172.16.1.207:4806/graphql";


const GET_WORKER_BY_CODIGO_QUERY = `
mutation GetWorkerByCodigo($codigo:String!){
  getWorker(codigo:$codigo){
    ok
     worker{ id nombres apellidos sexo dni }
    errors { message }
  }
}`;

const GET_WORKER_BY_DNI_QUERY = `
mutation GetWorkerByDni($dni:String!){
   getWorker(dni:$dni){
    ok
    worker{ id nombres apellidos sexo dni }
    errors { message }
  }
}`;

const GET_WORKER_BY_DOCUMENTO_QUERY = `
mutation GetWorkerByDocumento($documento:String!){
  getWorker(documento:$documento){
    ok
    worker{ id nombres apellidos dni }
    errors { message }
  }
}`;

const GET_WORKER_BY_POR_DNI_QUERY = `
mutation GetWorkerByPorDni($porDni:String!){
  getWorker(porDni:$porDni){
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

const fetchTrabajador = async ({ query, variables, lookupType }) => {
  console.info("GraphQL lookup request", {
    lookupType,
    url: WORKERS_API_URL,
    query: query.replace(/\s+/g, " ").trim(),
    variables,
  });



  
  const response = await fetch(WORKERS_API_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    cache: "no-store",
    body: JSON.stringify({
      query,
      variables,
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

  const responsePayload = payload?.data?.getWorker;
  if (payloadErrors.length && !responsePayload) {
    throw buildError("TRABAJADOR_GQL_ERROR", "TRABAJADOR_GQL_ERROR");
  }
  const worker = responsePayload?.worker;
  const ok = responsePayload?.ok;
  const errors = responsePayload?.errors;

  if (!ok || !worker) {
    const msg = Array.isArray(errors) && errors.length
      ? errors.map((e) => e?.message).filter(Boolean).join(", ")
      : null;
    if (msg) console.error("getWorker errors:", msg);

    throw buildError("TRABAJADOR_NO_ENCONTRADO", "TRABAJADOR_NO_ENCONTRADO");
  }

  return {
    codigo: worker.id,
    dni: worker.dni ?? null,
    sexo: worker.sexo ?? null,
    nombre: `${worker.nombres} ${worker.apellidos}`.trim(),
  };
};

const getTrabajadorPorCodigo = async (codigo) => {
  const codigoTrim = String(codigo ?? "").trim();
  if (!codigoTrim) {
    throw buildError("TRABAJADOR_NO_ENCONTRADO", "TRABAJADOR_NO_ENCONTRADO");
  }

  return fetchTrabajador({
    query: GET_WORKER_BY_CODIGO_QUERY,
    variables: { codigo: codigoTrim },
    lookupType: "codigo",
  });
};

const getTrabajadorPorDni = async (dni) => {
  const dniTrim = String(dni ?? "").trim();
  if (!dniTrim) {
    throw buildError("TRABAJADOR_NO_ENCONTRADO", "TRABAJADOR_NO_ENCONTRADO");
  }

  const dniStrategies = [
    {
      argName: "dni",
      query: GET_WORKER_BY_DNI_QUERY,
      variables: { dni: dniTrim },
    },
    {
      argName: "documento",
      query: GET_WORKER_BY_DOCUMENTO_QUERY,
      variables: { documento: dniTrim },
    },
    {
      argName: "porDni",
      query: GET_WORKER_BY_POR_DNI_QUERY,
      variables: { porDni: dniTrim },
    },
  ];

  let lastError = null;

  for (const strategy of dniStrategies) {
    try {
      return await fetchTrabajador({
        query: strategy.query,
        variables: strategy.variables,
        lookupType: `dni:${strategy.argName}`,
      });
    } catch (error) {
      lastError = error;
      if (error?.code === "TRABAJADOR_NO_ENCONTRADO") {
        throw error;
      }
      console.warn("Fallo lookup DNI con argumento GraphQL", {
        argName: strategy.argName,
        error: error?.message,
      });
    }
  }

  throw lastError || buildError("TRABAJADOR_GQL_ERROR", "TRABAJADOR_GQL_ERROR");
};

module.exports = { getTrabajadorPorCodigo, getTrabajadorPorDni };
