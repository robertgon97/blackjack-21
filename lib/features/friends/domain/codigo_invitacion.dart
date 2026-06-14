/// Normalización del código de invitación (capa domain — sin Flutter ni Firebase).
///
/// Los códigos tienen formato canónico `BJ-XXXX` (ver `_generarCodigo` en
/// `auth/data`). El usuario suele teclearlos con variaciones (sin el guion, en
/// minúsculas, con espacios), así que se normalizan antes de buscar.
library;

/// Lleva un código tecleado al formato canónico `BJ-XXXX`.
///
/// Tolera minúsculas, espacios y la **falta del guion** (`bjab12`, `BJ AB12`,
/// `bj-ab12` → `BJ-AB12`). Si la entrada no empieza por `BJ` o es demasiado
/// corta, devuelve solo los caracteres alfanuméricos en mayúscula (que no
/// coincidirá con ningún código real, y la búsqueda dará "no encontrado").
String normalizarCodigoInvitacion(String input) {
  final limpio = input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (limpio.length <= 2 || !limpio.startsWith('BJ')) return limpio;
  return 'BJ-${limpio.substring(2)}';
}
