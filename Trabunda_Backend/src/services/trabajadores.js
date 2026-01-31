const { getTrabajadorPorCodigo: getTrabajadorGraphql } = require("./trabajadorApi");

  const normalizeTrabajador = (payload, codigoFallback) => {
  if (!payload) return null;

  return {
     id: payload.id ?? null,
    codigo: (payload.codigo ?? codigoFallback ?? "").toString().trim(),
    dni: payload.dni ?? null,
    nombre_completo: (payload.nombre_completo ?? payload.nombre ?? "").toString(),
  };
};



const getTrabajadorPorCodigo = async (codigo) => {
  const codigoLimpio = String(codigo ?? "").trim();
  if (!codigoLimpio) return null;

  

  try {
    const trabajador = await getTrabajadorGraphql(codigoLimpio);
    return normalizeTrabajador(trabajador, codigoLimpio);
  } catch (error) {
    if (error?.code === "TRABAJADOR_NO_ENCONTRADO") {
      return null;
    }

    if (error?.code === "TRABAJADOR_GQL_NO_CONFIG") {
      return {
        error: error.message,
        status: 501,
      };
    }

   
    return {
      error: error?.message || "No se pudo conectar al servicio de trabajadores",
      status: 502,
    };
  }
};

module.exports = { getTrabajadorPorCodigo };
