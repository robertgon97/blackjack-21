import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/i_profile_repository.dart';

/// Implementación de [IProfileRepository] leyendo `users/{uid}` de Firestore.
/// Las `stats` y `logros` los escribe la Cloud Function `playerAction`; aquí solo
/// se leen (el cliente no puede tocarlos, ver `firestore.rules`).
class FirestoreProfileRepository implements IProfileRepository {
  FirestoreProfileRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Stream<Map<String, dynamic>> usuarioDocStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map(
          (doc) => doc.data() ?? const <String, dynamic>{},
        );
  }
}
