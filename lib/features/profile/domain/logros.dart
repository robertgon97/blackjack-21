/// Catálogo de logros (Fase 9 — capa domain, sin Flutter ni Firebase).
///
/// Espejo de la metadata de `functions/src/logros.ts`: aquí están el nombre, el
/// emoji y la descripción para la **galería** de la UI; allá están las
/// condiciones que la Cloud Function evalúa server-side (anti-trampa). Los `id`
/// deben coincidir exactamente en ambos lados. Al añadir/cambiar un logro,
/// actualizar los dos archivos.
library;

/// Definición de un logro para mostrarlo en la galería.
class Logro {
  const Logro({
    required this.id,
    required this.emoji,
    required this.nombre,
    required this.descripcion,
  });

  final String id;
  final String emoji;
  final String nombre;

  /// Cómo se desbloquea (texto para la UI).
  final String descripcion;
}

/// Todos los logros, en el orden en que se muestran en la galería.
const List<Logro> catalogoLogros = [
  Logro(
    id: 'primera',
    emoji: '🎉',
    nombre: 'Primera victoria',
    descripcion: 'Gana tu primera mano.',
  ),
  Logro(
    id: 'bj',
    emoji: '🃏',
    nombre: '¡Blackjack!',
    descripcion: 'Consigue un blackjack.',
  ),
  Logro(
    id: 'racha3',
    emoji: '🔥',
    nombre: '3 seguidas',
    descripcion: 'Gana 3 rondas consecutivas.',
  ),
  Logro(
    id: 'racha5',
    emoji: '🔥🔥',
    nombre: '5 seguidas',
    descripcion: 'Gana 5 rondas consecutivas.',
  ),
  Logro(
    id: 'veterano',
    emoji: '🎖️',
    nombre: 'Veterano',
    descripcion: 'Juega 50 manos.',
  ),
  Logro(
    id: 'centenario',
    emoji: '💯',
    nombre: 'Centenario',
    descripcion: 'Juega 100 manos.',
  ),
  Logro(
    id: 'granGanancia',
    emoji: '💰',
    nombre: 'Gran ganancia',
    descripcion: 'Gana 500 o más en una sola ronda.',
  ),
  Logro(
    id: 'ricachon',
    emoji: '💎',
    nombre: 'Ricachón',
    descripcion: 'Alcanza un saldo de 5000.',
  ),
];

/// Busca un logro por su [id]; `null` si no está en el catálogo (p. ej. un id
/// nuevo escrito por una versión más reciente de la Function).
Logro? logroPorId(String id) {
  for (final l in catalogoLogros) {
    if (l.id == id) return l;
  }
  return null;
}
