const fetch = global.fetch;

if (!fetch) {
  throw new Error("FETCH_NO_DISPONIBLE");
}

const WORKERS_API_URL =
  process.env.WORKERS_API_URL || "http://vserver.trabunda.com:3000/graphql";

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

const buildError = (message, code) => {
  const error = new Error(message);
  error.code = code;
  return error;
};

const fetchTrabajador = async ({ query, variables, lookupType }) => {
  console.info("GraphQL lookup request", {
    lookupType,
    url: WORKERS_API_URL,
    variables,
  });

  const headers = { "Content-Type": "application/json" };

  console.log("=== GRAPHQL REQUEST DEBUG ===");
  console.log("WORKERS_API_URL:", process.env.WORKERS_API_URL);
  console.log("Query:", query);
  console.log("Variables:", JSON.stringify(variables, null, 2));
  console.log("Headers:", headers);

  const response = await fetch(WORKERS_API_URL, {
    method: "POST",
    headers,
    cache: "no-store",
    body: JSON.stringify({ query, variables }),
  });

  let payload;
  try {
    payload = await response.json();
    console.log("=== GRAPHQL RESPONSE DEBUG ===");
    console.log("Status:", response.status);
    console.log("StatusText:", response.statusText);
    console.log("Response body:", JSON.stringify(payload, null, 2));
  } catch (error) {
    console.error("Error parseando JSON de trabajadores", {
      status: response.status,
      url: response.url || WORKERS_API_URL,
      error: error?.message,
    });
    throw buildError("TRABAJADOR_GQL_ERROR", "TRABAJADOR_GQL_ERROR");
  }

  if (!response.ok) {
    console.error("Respuesta no OK desde trabajadores", {
      status: response.status,
      url: response.url || WORKERS_API_URL,
      payload,
    });
    throw buildError("TRABAJADOR_GQL_ERROR", "TRABAJADOR_GQL_ERROR");
  }

  const responsePayload = payload?.data?.getWorker;
  const worker = responsePayload?.worker;

  if (!responsePayload?.ok || !worker) {
    throw buildError("TRABAJADOR_NO_ENCONTRADO", "TRABAJADOR_NO_ENCONTRADO");
  }

  return {
    codigo: worker.id,
    dni: worker.dni ?? null,
    sexo: worker.sexo ?? null,
    nombre: `${worker.nombres ?? ""} ${worker.apellidos ?? ""}`.trim(),
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

  return fetchTrabajador({
    query: GET_WORKER_BY_DNI_QUERY,
    variables: { dni: dniTrim },
    lookupType: "dni",
  });
};

module.exports = { getTrabajadorPorCodigo, getTrabajadorPorDni };
