function timeToMinutes(timeValue) {
  if (timeValue === null || timeValue === undefined) return null;

  const [hhRaw, mmRaw] = String(timeValue).split(":");
  const hh = Number(hhRaw);
  const mm = Number(mmRaw);

  if (!Number.isInteger(hh) || !Number.isInteger(mm)) return null;
  if (hh < 0 || hh > 23 || mm < 0 || mm > 59) return null;

  return hh * 60 + mm;
}

function calcularDiferenciaMinutos(horaInicio, horaFin) {
  const inicioMin = timeToMinutes(horaInicio);
  const finMinOriginal = timeToMinutes(horaFin);

  if (inicioMin === null || finMinOriginal === null) {
    throw new Error("Formato de hora inválido");
  }

  let finMin = finMinOriginal;
  if (finMin < inicioMin) {
    finMin += 24 * 60;
  }

  return finMin - inicioMin;
}

function redondearMediaHora(duracionHoras, roundingMode = "round") {
  if (roundingMode === "floor") {
    return Math.floor(duracionHoras * 2) / 2;
  }

  return Math.round(duracionHoras * 2) / 2;
}

function calcHorasConAlmuerzo(horaInicio, horaFin, options = {}) {
  const { roundingMode = "round" } = options;

  const inicioMin = timeToMinutes(horaInicio);
  const finMinOriginal = timeToMinutes(horaFin);

  if (inicioMin === null || finMinOriginal === null) {
    throw new Error("Formato de hora inválido");
  }

  let finMin = finMinOriginal;
  if (finMin < inicioMin) {
    finMin += 24 * 60;
  }

  let duracionMin = finMin - inicioMin;
  duracionMin -= 30;

  if (duracionMin < 0) {
    return 0;
  }

  const duracionHoras = duracionMin / 60;
  const redondeado = redondearMediaHora(duracionHoras, roundingMode);

  return Number(redondeado.toFixed(1));
}

module.exports = {
  calcHorasConAlmuerzo,
  calcularDiferenciaMinutos,
  timeToMinutes,
};
