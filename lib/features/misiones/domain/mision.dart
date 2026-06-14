/// Catálogo de misiones diarias/semanales (Fase 10c — capa domain, sin Flutter
/// ni Firebase).
///
/// Espejo de `functions/src/misiones.ts`: aquí están la metadata y las metas para
/// la UI; allá se valida el reclamo server-side (anti-trampa). Los `id`, metas y
/// recompensas deben coincidir en ambos lados.
library;

/// Periodo de una misión.
enum TipoMision {
  diaria('Diarias'),
  semanal('Semanales');

  const TipoMision(this.etiqueta);

  final String etiqueta;
}

/// Métrica de progreso de una misión. `campo` es la clave en el documento de
/// progreso `users/{uid}/progreso/{periodo}` que escribe `playerAction`.
enum MetricaMision {
  manosJugadas('manosJugadas'),
  ganadas('ganadas'),
  blackjacks('blackjacks'),
  gananciaNeta('gananciaNeta');

  const MetricaMision(this.campo);

  final String campo;
}

/// Definición de una misión.
class Mision {
  const Mision({
    required this.id,
    required this.tipo,
    required this.metrica,
    required this.meta,
    required this.recompensa,
    required this.descripcion,
  });

  final String id;
  final TipoMision tipo;
  final MetricaMision metrica;

  /// Valor objetivo de la métrica para completarla.
  final int meta;

  /// Créditos que otorga al reclamarse.
  final int recompensa;
  final String descripcion;
}

/// Todas las misiones, en el orden en que se muestran.
const List<Mision> catalogoMisiones = [
  // Diarias.
  Mision(
    id: 'd_jugar',
    tipo: TipoMision.diaria,
    metrica: MetricaMision.manosJugadas,
    meta: 5,
    recompensa: 100,
    descripcion: 'Juega 5 manos hoy',
  ),
  Mision(
    id: 'd_ganar',
    tipo: TipoMision.diaria,
    metrica: MetricaMision.ganadas,
    meta: 3,
    recompensa: 150,
    descripcion: 'Gana 3 manos hoy',
  ),
  Mision(
    id: 'd_blackjack',
    tipo: TipoMision.diaria,
    metrica: MetricaMision.blackjacks,
    meta: 1,
    recompensa: 200,
    descripcion: 'Consigue un blackjack hoy',
  ),
  // Semanales.
  Mision(
    id: 's_jugar',
    tipo: TipoMision.semanal,
    metrica: MetricaMision.manosJugadas,
    meta: 50,
    recompensa: 500,
    descripcion: 'Juega 50 manos esta semana',
  ),
  Mision(
    id: 's_ganar',
    tipo: TipoMision.semanal,
    metrica: MetricaMision.ganadas,
    meta: 20,
    recompensa: 700,
    descripcion: 'Gana 20 manos esta semana',
  ),
  Mision(
    id: 's_ganancia',
    tipo: TipoMision.semanal,
    metrica: MetricaMision.gananciaNeta,
    meta: 2000,
    recompensa: 1000,
    descripcion: 'Gana 2000 créditos netos esta semana',
  ),
];
