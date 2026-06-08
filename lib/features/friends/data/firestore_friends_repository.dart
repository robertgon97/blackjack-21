import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../domain/contacto.dart';
import '../domain/i_friends_repository.dart';
import '../domain/resultado_busqueda.dart';

/// Implementación de [IFriendsRepository] sobre Firestore + Cloud Functions.
class FirestoreFriendsRepository implements IFriendsRepository {
  FirestoreFriendsRepository({
    FirebaseFirestore? db,
    FirebaseFunctions? functions,
  })  : _db = db ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(
          region: 'southamerica-east1',
        );

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  @override
  Stream<List<Contacto>> contactosStream(String uid) {
    return _db
        .collection('friendships')
        .doc(uid)
        .collection('contacts')
        .orderBy('since', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map(_docAContacto).toList(),
        );
  }

  @override
  Future<ResultadoBusqueda?> buscarPorCodigo(String inviteCode) async {
    final code = inviteCode.trim().toUpperCase();
    if (code.isEmpty) return null;
    final doc = await _db.collection('invite_codes').doc(code).get();
    if (!doc.exists) return null;
    final d = doc.data()!;
    return ResultadoBusqueda(
      uid: d['uid'] as String,
      displayName: d['displayName'] as String? ?? 'Jugador',
      avatar: d['avatar'] as String? ?? '🃏',
    );
  }

  @override
  Future<void> enviarSolicitud({
    required String myUid,
    required String myDisplayName,
    required String myAvatar,
    required ResultadoBusqueda amigo,
  }) async {
    final batch = _db.batch();
    final ts = FieldValue.serverTimestamp();
    final datosBase = {
      'status': 'pending',
      'initiatedBy': myUid,
      'since': ts,
    };

    // Mi lado: guardo la info del amigo.
    batch.set(
      _db.doc('friendships/$myUid/contacts/${amigo.uid}'),
      {
        ...datosBase,
        'displayName': amigo.displayName,
        'avatar': amigo.avatar,
      },
    );

    // Su lado: guardo mi info (permitido por reglas de Firestore extendidas).
    batch.set(
      _db.doc('friendships/${amigo.uid}/contacts/$myUid'),
      {
        ...datosBase,
        'displayName': myDisplayName,
        'avatar': myAvatar,
      },
    );

    await batch.commit();
  }

  @override
  Future<void> aceptarSolicitud({
    required String myUid,
    required String friendUid,
  }) async {
    final batch = _db.batch();
    final update = {'status': 'accepted'};
    batch.update(_db.doc('friendships/$myUid/contacts/$friendUid'), update);
    batch.update(_db.doc('friendships/$friendUid/contacts/$myUid'), update);
    await batch.commit();
  }

  @override
  Future<void> eliminarContacto({
    required String myUid,
    required String friendUid,
  }) async {
    final batch = _db.batch();
    batch.delete(_db.doc('friendships/$myUid/contacts/$friendUid'));
    batch.delete(_db.doc('friendships/$friendUid/contacts/$myUid'));
    await batch.commit();
  }

  @override
  Future<void> transferirCreditos({
    required String toUid,
    required int monto,
  }) async {
    await _functions.httpsCallable('transferCredits').call<void>({
      'toUid': toUid,
      'monto': monto,
    });
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  Contacto _docAContacto(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return Contacto(
      uid: doc.id,
      displayName: d['displayName'] as String? ?? 'Jugador',
      avatar: d['avatar'] as String? ?? '🃏',
      estado: (d['status'] as String?) == 'accepted'
          ? EstadoAmistad.aceptada
          : EstadoAmistad.pendiente,
      initiatedBy: d['initiatedBy'] as String? ?? '',
      since: (d['since'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
