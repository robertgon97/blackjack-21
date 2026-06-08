import 'contacto.dart';
import 'resultado_busqueda.dart';

/// Contrato del módulo social. La capa data implementa esta interfaz;
/// la presentación solo la conoce a través de los providers.
abstract interface class IFriendsRepository {
  /// Stream de contactos del usuario (pendientes + aceptados), orden por fecha.
  Stream<List<Contacto>> contactosStream(String uid);

  /// Busca un usuario por su código de invitación en la colección `invite_codes`.
  /// Retorna `null` si el código no existe.
  Future<ResultadoBusqueda?> buscarPorCodigo(String inviteCode);

  /// Envía solicitud de amistad: escribe ambos lados de la relación en Firestore.
  Future<void> enviarSolicitud({
    required String myUid,
    required String myDisplayName,
    required String myAvatar,
    required ResultadoBusqueda amigo,
  });

  /// Acepta una solicitud recibida: actualiza ambos lados a `accepted`.
  Future<void> aceptarSolicitud({
    required String myUid,
    required String friendUid,
  });

  /// Rechaza o elimina un contacto: borra ambos lados.
  Future<void> eliminarContacto({
    required String myUid,
    required String friendUid,
  });

  /// Transfiere créditos a un amigo vía Cloud Function `transferCredits`.
  Future<void> transferirCreditos({
    required String toUid,
    required int monto,
  });
}
