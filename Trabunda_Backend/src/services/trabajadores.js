const normalizeTrabajador = (payload) => {
  if (!payload) return null;

  const record = Array.isArray(payload) ? payload[0] : payload;
  if (!record) return null;

  return {
    id: record.id ?? record.trabajador_id ?? null,
    codigo: (record.codigo ?? record.trabajador_codigo ?? "").toString().trim(),
    dni: (record.dni ?? record.documento ?? "").toString(),
    nombre_completo: (
      record.nombre_completo ??
      record.nombre ??
      record.trabajador_nombre ??
      ""
    ).toString(),
  };
};

const buildLookupUrl = (codigo) => {
  const baseUrl = process.env.TRABAJADORES_API_URL;
  if (!baseUrl) return null;

  const lookupPath =
    process.env.TRABAJADORES_API_LOOKUP_PATH || "/trabajadores/lookup";
  const url = new URL(lookupPath, baseUrl);
  url.searchParams.set("q", codigo);
  url.searchParams.set("codigo", codigo);
  return url.toString();
};

const getTrabajadorPorCodigo = async (codigo) => {
  const codigoLimpio = String(codigo ?? "").trim();
  if (!codigoLimpio) return null;

  const url = buildLookupUrl(codigoLimpio);
  if (!url) {
    return {
      error: "Servicio de trabajadores no configurado",
      status: 501,
    };
  }

  try {
    const response = await fetch(url, {
      headers: {
        Accept: "application/json",
      },
    });
    const rawText = await response.text();

    let data = null;
    if (rawText) {
      try {
        data = JSON.parse(rawText);
      } catch (error) {
        return {
          error: "Respuesta inválida del servicio de trabajadores",
          status: 502,
        };
      }
    }

    if (!response.ok) {
      const message =
        data && typeof data === "object" && data.error
          ? data.error
          : `Error servicio trabajadores (HTTP ${response.status})`;
      return {
        error: message,
        status: response.status === 404 ? 404 : 502,
      };
    }

    return normalizeTrabajador(data);
  } catch (error) {
    return {
      error: "No se pudo conectar al servicio de trabajadores",
      status: 502,
    };
  }
};

module.exports = { getTrabajadorPorCodigo };
