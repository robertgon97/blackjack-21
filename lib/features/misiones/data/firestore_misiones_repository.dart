import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../domain/i_misiones_repository.dart';
import '../domain/progreso_periodo.dart';

/// Implementación de [IMisionesRepository] sobre Firestore + Cloud Functions. El
/// progreso lo escribe `playerAction` y la recompensa la paga `claimMission`
/// (el cliente solo lee el progreso, ver `firestore.rules`).
class FirestoreMisionesRepository implements IMisionesRepository {
  FirestoreMisionesRepository({
    FirebaseFirestore? db,
    FirebaseFunctions? functions,
  })  : _db = db ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'southamerica-east1');

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  @override
  Stream<ProgresoPeriodo> progresoStream(String uid, String periodoId) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('progreso')
        .doc(periodoId)
        .snapshots()
        .map((doc) => ProgresoPeriodo.fromMap(doc.data()));
  }

  @override
  Future<int> reclamarMision(String missionId) async {
    try {
      final res = await _functions
          .httpsCallable('claimMission')
          .call<Object?>({'missionId': missionId});
      final data = res.data as Map<Object?, Object?>;
      return (data['balance'] as num?)?.toInt() ?? 0;
    } on FirebaseFunctionsException catch (e) {
      final mensaje = switch (e.code) {
        'failed-precondition' =>
          e.message ?? 'Aún no puedes reclamar esta misión.',
        'already-exists' => 'Ya reclamaste esta misión.',
        'unauthenticated' => 'Inicia sesión para reclamar la misión.',
        'not-found' => 'Misión no encontrada.',
        _ => 'No se pudo reclamar la misión. Intenta de nuevo.',
      };
      throw Exception(mensaje);
    }
  }
}
