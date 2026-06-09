/// Estados posibles de una relación de amistad.
enum EstadoAmistad { pendiente, aceptada }

/// Representa un contacto en la lista del usuario: amigo aceptado o solicitud pendiente.
class Contacto {
  const Contacto({
    required this.uid,
    required this.displayName,
    required this.avatar,
    required this.estado,
    required this.initiatedBy,
    required this.since,
  });

  final String uid;
  final String displayName;
  final String avatar;
  final EstadoAmistad estado;

  /// UID de quien envió la solicitud original.
  final String initiatedBy;
  final DateTime since;

  /// Indica si el usuario identificado como [myUid] fue quien envió la solicitud.
  bool yoEnvie(String myUid) => initiatedBy == myUid;
}
