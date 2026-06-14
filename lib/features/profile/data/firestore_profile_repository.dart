import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/estadisticas.dart';
import '../domain/i_profile_repository.dart';

/// Implementación de [IProfileRepository] leyendo `users/{uid}.stats` de
/// Firestore. Las stats las escribe la Cloud Function `playerAction`; aquí solo
/// se leen (el cliente no puede tocarlas, ver `firestore.rules`).
class FirestoreProfileRepository implements IProfileRepository {
  FirestoreProfileRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Stream<Estadisticas> estadisticasStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      final stats = doc.data()?['stats'] as Map<String, dynamic>?;
      return Estadisticas.fromMap(stats);
    });
  }
}
