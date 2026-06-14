import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/datos_usuario.dart';
import '../domain/estadisticas.dart';
import '../domain/i_profile_repository.dart';

/// Implementación de [IProfileRepository] leyendo `users/{uid}` de Firestore.
/// Las `stats` y `logros` los escribe la Cloud Function `playerAction`; aquí solo
/// se leen (el cliente no puede tocarlos, ver `firestore.rules`).
class FirestoreProfileRepository implements IProfileRepository {
  FirestoreProfileRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Stream<DatosUsuario> datosStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      final data = doc.data();
      final stats = data?['stats'] as Map<String, dynamic>?;
      // `whereType` descarta de forma segura cualquier elemento no-String en vez
      // de lanzar (lo que sí haría `cast<String>()` en runtime).
      final logros =
          (data?['logros'] as List<dynamic>?)?.whereType<String>().toList() ??
              const <String>[];
      return DatosUsuario(
        estadisticas: Estadisticas.fromMap(stats),
        logros: logros,
      );
    });
  }
}
