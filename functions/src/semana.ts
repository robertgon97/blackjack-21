// ─────────────────────────────────────────────────────────────────────────────
// Identificador de semana ISO-8601 (`YYYY-Www`). Espejo de
// lib/core/utils/semana.dart. Define el periodo de los leaderboards
// (`leaderboards/{periodo}`). Se calcula en UTC.
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Devuelve el identificador de semana ISO-8601 de [fecha] como `YYYY-Www`.
 * Semana en lunes; la semana 1 contiene el primer jueves del año; el año es el
 * del jueves de esa semana.
 */
export function idSemanaIso(fecha: Date): string {
  const d = new Date(
    Date.UTC(fecha.getUTCFullYear(), fecha.getUTCMonth(), fecha.getUTCDate()),
  );
  // getUTCDay: 0=domingo..6=sábado → normalizar a 1=lunes..7=domingo.
  const diaSemana = d.getUTCDay() === 0 ? 7 : d.getUTCDay();
  // Avanzar al jueves de esta semana.
  d.setUTCDate(d.getUTCDate() + 4 - diaSemana);
  const inicioAnio = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  const semana = Math.ceil(
    ((d.getTime() - inicioAnio.getTime()) / 86400000 + 1) / 7,
  );
  return `${d.getUTCFullYear()}-W${String(semana).padStart(2, '0')}`;
}
