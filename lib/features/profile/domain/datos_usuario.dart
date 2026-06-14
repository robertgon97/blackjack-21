import 'estadisticas.dart';

/// Datos de progresión del usuario leídos del documento `users/{uid}`:
/// estadísticas de juego y logros desbloqueados.
///
/// Permite que el repositorio exponga un **único** stream del documento (un solo
/// listener de Firestore para stats + logros) sin filtrar la forma cruda del doc
/// a la capa de presentación.
class DatosUsuario {
  const DatosUsuario({required this.estadisticas, required this.logros});

  final Estadisticas estadisticas;

  /// IDs de logros desbloqueados (ver `logros.dart` para su metadata).
  final List<String> logros;

  /// Datos de un usuario sin partidas ni logros.
  static const DatosUsuario vacios = DatosUsuario(
    estadisticas: Estadisticas.vacias,
    logros: <String>[],
  );
}
