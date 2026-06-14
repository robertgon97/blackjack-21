import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/semana.dart';
import '../domain/entrada_ranking.dart';
import '../domain/i_leaderboard_repository.dart';

/// Implementación de [ILeaderboardRepository] sobre Firestore. El periodo es la
/// semana ISO actual; las entradas las escribe `playerAction` (el cliente solo
/// lee, ver `firestore.rules`).
class FirestoreLeaderboardRepository implements ILeaderboardRepository {
  FirestoreLeaderboardRepository({
    FirebaseFirestore? db,
    DateTime Function()? ahora,
  })  : _db = db ?? FirebaseFirestore.instance,
        _ahora = ahora ?? DateTime.now;

  final FirebaseFirestore _db;
  final DateTime Function() _ahora;

  CollectionReference<Map<String, dynamic>> get _entries => _db
      .collection('leaderboards')
      .doc(idSemanaIso(_ahora()))
      .collection('entries');

  @override
  Stream<List<EntradaRanking>> topGlobal(
    MetricaRanking metrica, {
    int limite = 50,
  }) {
    return _entries
        .orderBy(metrica.campo, descending: true)
        .limit(limite)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => EntradaRanking.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  @override
  Future<List<EntradaRanking>> topAmigos(
    List<String> uids,
    MetricaRanking metrica,
  ) async {
    if (uids.isEmpty) return const [];
    // Lectura puntual por id (los amigos son pocos): evita el operador `in` y
    // el índice compuesto que exigiría combinarlo con orderBy.
    final docs = await Future.wait(uids.map((uid) => _entries.doc(uid).get()));
    final entradas = docs
        .where((d) => d.exists)
        .map((d) => EntradaRanking.fromMap(d.id, d.data()!))
        .toList();
    entradas.sort((a, b) => b.valor(metrica).compareTo(a.valor(metrica)));
    return entradas;
  }

  @override
  Future<EntradaRanking?> entradaDe(String uid) async {
    final doc = await _entries.doc(uid).get();
    if (!doc.exists) return null;
    return EntradaRanking.fromMap(doc.id, doc.data()!);
  }

  @override
  Future<int> posicionGlobal(MetricaRanking metrica, int miValor) async {
    // Posición = nº de entradas con un valor estrictamente mayor, más uno.
    // Usa el agregado count() de Firestore (no descarga los documentos).
    final mayores = await _entries
        .where(metrica.campo, isGreaterThan: miValor)
        .count()
        .get();
    return (mayores.count ?? 0) + 1;
  }
}
