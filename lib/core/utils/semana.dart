// ============================================================
//  Identificador de semana ISO-8601 (puro, sin Flutter)
//
//  Punto único para derivar el periodo semanal de los leaderboards
//  (`leaderboards/{periodo}`). Espejo de `functions/src/semana.ts`.
// ============================================================

/// Devuelve el identificador de semana ISO-8601 de [fecha] como `YYYY-Www`
/// (p. ej. `2026-W24`).
///
/// La semana empieza en **lunes** y la semana 1 es la que contiene el primer
/// jueves del año; el año del identificador es el del jueves de esa semana (por
/// eso los últimos días de diciembre pueden caer en la semana 1 del año
/// siguiente, y viceversa). Se calcula en UTC para que el periodo no dependa de
/// la zona horaria del dispositivo.
String idSemanaIso(DateTime fecha) {
  // Normaliza a medianoche UTC; el jueves de la semana define año y número.
  final d = DateTime.utc(fecha.year, fecha.month, fecha.day);
  final jueves = d.add(Duration(days: 4 - d.weekday)); // weekday: 1=lun..7=dom
  final inicioAnio = DateTime.utc(jueves.year, 1, 1);
  final semana = 1 + (jueves.difference(inicioAnio).inDays ~/ 7);
  return '${jueves.year}-W${semana.toString().padLeft(2, '0')}';
}
