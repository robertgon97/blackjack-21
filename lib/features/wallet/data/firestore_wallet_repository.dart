import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/utils/semana.dart';
import '../domain/bono_diario.dart';
import '../domain/i_wallet_repository.dart';
import '../domain/transaccion.dart';

/// Implementación de [IWalletRepository] leyendo Firestore. El bono diario, que
/// escribe el saldo, se delega a una Cloud Function (el cliente no puede tocar
/// `balance`).
class FirestoreWalletRepository implements IWalletRepository {
  FirestoreWalletRepository({
    FirebaseFirestore? db,
    FirebaseFunctions? functions,
  })  : _db = db ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'southamerica-east1');

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  @override
  Future<ResultadoBonoDiario> reclamarBonoDiario() async {
    try {
      final res =
          await _functions.httpsCallable('claimDailyBonus').call<Object?>();
      final data = res.data as Map<Object?, Object?>;
      return ResultadoBonoDiario(
        balance: (data['balance'] as num).toInt(),
        monto: (data['amount'] as num).toInt(),
        racha: (data['streak'] as num).toInt(),
      );
    } on FirebaseFunctionsException catch (e) {
      final mensaje = switch (e.code) {
        'failed-precondition' =>
          e.message ?? 'Aún no puedes reclamar el bono diario.',
        'unauthenticated' => 'Inicia sesión para reclamar el bono.',
        'not-found' => 'No se encontró tu perfil.',
        _ => 'No se pudo reclamar el bono. Intenta de nuevo.',
      };
      throw Exception(mensaje);
    }
  }

  @override
  Stream<EstadoBonoDiario> estadoBonoStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      final data = doc.data();
      final racha = (data?['dailyStreak'] as num?)?.toInt() ?? 0;
      // Día del último reclamo (compat con cuentas que solo tienen el timestamp).
      final lastDay = data?['lastDailyBonusDay'] as String?;
      final lastTs = data?['lastDailyBonus'] as Timestamp?;
      final ultimoDia =
          lastDay ?? (lastTs != null ? idDiaUtc(lastTs.toDate()) : null);

      final ahora = DateTime.now();
      final hoy = idDiaUtc(ahora);
      final ayer = idDiaUtc(ahora.subtract(const Duration(days: 1)));

      // La racha solo sigue vigente si el último reclamo fue hoy o ayer.
      final rachaVigente = (ultimoDia == hoy || ultimoDia == ayer) ? racha : 0;
      return EstadoBonoDiario(
        racha: rachaVigente,
        disponibleHoy: ultimoDia != hoy,
      );
    });
  }

  @override
  Stream<int> saldoStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => (doc.data()?['balance'] as int?) ?? 0);
  }

  @override
  Stream<List<Transaccion>> transaccionesStream(String uid, {int limite = 50}) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .orderBy('createdAt', descending: true)
        .limit(limite)
        .snapshots()
        .map(
          (snap) => snap.docs.map(_docATransaccion).toList(),
        );
  }

  Transaccion _docATransaccion(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Transaccion(
      id: doc.id,
      tipo: _parseTipo(d['type'] as String? ?? 'win'),
      monto: d['amount'] as int? ?? 0,
      balanceAfter: d['balance_after'] as int? ?? 0,
      descripcion: d['description'] as String? ?? '',
      fecha: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      gameId: d['gameId'] as String?,
      fromUid: d['fromUid'] as String?,
      toUid: d['toUid'] as String?,
    );
  }

  TipoTransaccion _parseTipo(String raw) {
    return switch (raw) {
      'win' => TipoTransaccion.win,
      'loss' => TipoTransaccion.loss,
      'push' => TipoTransaccion.push,
      'transfer_in' => TipoTransaccion.transferIn,
      'transfer_out' => TipoTransaccion.transferOut,
      'ad_reward' => TipoTransaccion.adReward,
      'bonus_registro' => TipoTransaccion.bonusRegistro,
      'bonus_invitacion' => TipoTransaccion.bonusInvitacion,
      'bonus_conversion' => TipoTransaccion.bonusConversion,
      'bonus_daily' => TipoTransaccion.bonusDaily,
      'mission_reward' => TipoTransaccion.misionRecompensa,
      _ => TipoTransaccion.win,
    };
  }
}
