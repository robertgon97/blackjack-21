// ============================================================
//  Identificador de semana ISO-8601 (puro, sin Flutter)
//
//  Punto único para derivar el periodo semanal de los leaderboards
//  (`leaderboards/{periodo}`). Espejo de `functions/src/semana.ts`.
// ============================================================

/// Día calendario en UTC como `YYYY-MM-DD`. Base de la racha del bono diario
/// (Fase 10b); espejo de `idDiaUtc` en `functions/src/semana.ts`. Usa UTC para
/// que cliente y servidor coincidan en el cambio de día.
String idDiaUtc(DateTime fecha) =>
    fecha.toUtc().toIso8601String().substring(0, 10);

/// Devuelve el identificador de semana ISO-8601 de [fecha] como `YYYY-Www`
/// (p. ej. `2026-W24`).
///
/// La semana empieza en **lunes** y la semana 1 es la que contiene el primer
/// jueves del año; el año del identificador es el del jueves de esa semana (por
/// eso los últimos días de diciembre pueden caer en la semana 1 del año
/// siguiente, y viceversa). Se calcula en UTC para que el periodo no dependa de
/// la zona horaria del dispositivo.
String idSemanaIso(DateTime fecha) {
  // Convertir a UTC ANTES de extraer los componentes: `fecha.year/month/day` de
  // un DateTime local darían la fecha local, que cerca de medianoche puede caer
  // en otro día (y otra semana) que la del servidor —que calcula en UTC—,
  // dejando al cliente leyendo un periodo vacío.
  final u = fecha.toUtc();
  // Normaliza a medianoche UTC; el jueves de la semana define año y número.
  final d = DateTime.utc(u.year, u.month, u.day);
  final jueves = d.add(Duration(days: 4 - d.weekday)); // weekday: 1=lun..7=dom
  final inicioAnio = DateTime.utc(jueves.year, 1, 1);
  final semana = 1 + (jueves.difference(inicioAnio).inDays ~/ 7);
  return '${jueves.year}-W${semana.toString().padLeft(2, '0')}';
}
