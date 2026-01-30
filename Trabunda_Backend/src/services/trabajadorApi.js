const fetch = global.fetch;

if (!fetch) {
  throw new Error('FETCH_NO_DISPONIBLE');
}

const TRABAJADOR_API_URL = process.env.TRABAJADOR_API_URL || 'http://trabajadorapi:4806/graphql';
const GET_WORKER_QUERY = `query GetWorker($codigo: String!) {
  getWorker(codigo: $codigo) {
    id
    nombres
    apellidos
  }
}`;

const buildNombreCompleto = (worker) => `${worker.nombres || ''} ${worker.apellidos || ''}`.trim();

const getTrabajadorPorCodigo = async (codigo) => {
  const response = await fetch(TRABAJADOR_API_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      query: GET_WORKER_QUERY,
      variables: { codigo },
    }),
  });

  if (!response.ok) {
    throw new Error('TRABAJADOR_NO_ENCONTRADO');
  }

  const payload = await response.json();
  const worker = payload?.data?.getWorker;

  if (!worker) {
    throw new Error('TRABAJADOR_NO_ENCONTRADO');
  }

  return {
    codigo: worker.id,
    nombre: buildNombreCompleto(worker),
  };
};

module.exports = {
  getTrabajadorPorCodigo,
};
