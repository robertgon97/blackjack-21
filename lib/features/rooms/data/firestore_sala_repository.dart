import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/telemetria/data/noop_telemetria.dart';
import '../../../core/telemetria/domain/i_servicio_telemetria.dart';
import '../domain/i_sala_repository.dart';
import '../domain/modelos.dart';

/// Implementación de [ISalaRepository] sobre Firestore + Cloud Functions.
class FirestoreSalaRepository implements ISalaRepository {
  FirestoreSalaRepository({
    FirebaseFirestore? db,
    FirebaseFunctions? functions,
    IServicioTelemetria? telemetria,
  })  : _db = db ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'southamerica-east1'),
        _telemetria = telemetria ?? const NoopTelemetria();

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  final IServicioTelemetria _telemetria;

  // ── Lobby ────────────────────────────────────────────────────────────────

  @override
  Stream<List<Sala>> salasPublicasStream() {
    return _db
        .collection('rooms')
        .where('private', isEqualTo: false)
        .where('status', whereIn: ['waiting', 'betting', 'playing'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => Sala.fromDoc(d.id, d.data())).toList(),
        );
  }

  // ── Sala individual ───────────────────────────────────────────────────────

  @override
  Stream<Sala?> salaStream(String roomId) {
    return _db.collection('rooms').doc(roomId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return Sala.fromDoc(snap.id, snap.data()!);
    });
  }

  @override
  Future<Sala?> buscarPorCodigo(String inviteCode) async {
    final code = inviteCode.trim().toUpperCase();
    if (code.isEmpty) return null;
    final snap = await _db
        .collection('rooms')
        .where('inviteCode', isEqualTo: code)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return Sala.fromDoc(doc.id, doc.data());
  }

  // ── Creación / entrada / salida ───────────────────────────────────────────

  @override
  Future<String> crearSala({
    required String hostUid,
    required String hostName,
    required String hostAvatar,
    required int hostBalance,
    required String nombre,
    required int maxJugadores,
    required bool privada,
    required ConfigSala config,
  }) async {
    final inviteCode = _generarCodigo();
    final ref = _db.collection('rooms').doc();
    final jugadorHost = JugadorEnSala(
      uid: hostUid,
      displayName: hostName,
      avatar: hostAvatar,
      balance: hostBalance,
      seat: 0,
    );
    await ref.set({
      'hostUid': hostUid,
      'hostName': hostName,
      'name': nombre,
      'status': 'waiting',
      'maxPlayers': maxJugadores,
      'private': privada,
      'inviteCode': inviteCode,
      'config': config.toMap(),
      'players': {hostUid: jugadorHost.toMap()},
      'currentGameId': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _telemetria.evento(
      'sala_creada',
      params: {
        'sala_id': ref.id,
        'privada': privada.toString(),
        'max_jugadores': maxJugadores,
      },
    );
    return ref.id;
  }

  @override
  Future<void> unirseASala({
    required String roomId,
    required String uid,
    required String displayName,
    required String avatar,
    required int balance,
    required bool comoEspectador,
  }) async {
    final ref = _db.collection('rooms').doc(roomId);
    // Transacción: el cálculo del asiento libre y la escritura ocurren de forma
    // atómica para evitar una race condition por el último asiento.
    await _db.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (!doc.exists) throw Exception('La sala no existe.');
      final sala = Sala.fromDoc(doc.id, doc.data()!);

      // Si ya está dentro, no se hace nada (idempotente).
      if (sala.players.containsKey(uid)) return;

      if (!comoEspectador && sala.estaLlena) {
        throw Exception('La sala está llena.');
      }
      if (sala.status == EstadoSala.playing) {
        throw Exception(
          'La partida ya comenzó; solo puedes entrar como espectador.',
        );
      }

      final seat =
          comoEspectador ? -1 : _proximoAsiento(sala.players.values.toList());

      final jugador = JugadorEnSala(
        uid: uid,
        displayName: displayName,
        avatar: avatar,
        balance: balance,
        seat: seat,
        isSpectator: comoEspectador,
      );
      tx.update(ref, {'players.$uid': jugador.toMap()});
    });
    await _telemetria.evento(
      'sala_unida',
      params: {
        'sala_id': roomId,
        'tipo': comoEspectador ? 'espectador' : 'jugador',
      },
    );
  }

  @override
  Future<void> salirDeSala({
    required String roomId,
    required String uid,
  }) async {
    await _db.collection('rooms').doc(roomId).update({
      'players.$uid': FieldValue.delete(),
    });
  }

  // ── Apuestas ─────────────────────────────────────────────────────────────

  @override
  Future<void> establecerApuesta({
    required String roomId,
    required String uid,
    required int apuesta,
  }) async {
    await _db.collection('rooms').doc(roomId).update({
      'players.$uid.apuesta': apuesta,
      'players.$uid.ready': false,
    });
  }

  @override
  Future<void> marcarListo({
    required String roomId,
    required String uid,
    required bool listo,
  }) async {
    await _db.collection('rooms').doc(roomId).update({
      'players.$uid.ready': listo,
    });
  }

  // ── Acciones del host ─────────────────────────────────────────────────────

  @override
  Future<void> cambiarEstadoSala({
    required String roomId,
    required EstadoSala nuevoEstado,
  }) async {
    final ref = _db.collection('rooms').doc(roomId);
    // Al volver a apostar hay que listar los jugadores y limpiar su ready/apuesta.
    // Esa lectura + escritura va en una transacción: si alguien se une entre el
    // get y el update, no se perdería la limpieza de su entrada.
    await _db.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (!doc.exists) return;
      final data = <String, dynamic>{'status': nuevoEstado.name};
      if (nuevoEstado == EstadoSala.betting) {
        final sala = Sala.fromDoc(doc.id, doc.data()!);
        for (final uid in sala.players.keys) {
          data['players.$uid.ready'] = false;
          data['players.$uid.apuesta'] = FieldValue.delete();
        }
      }
      tx.update(ref, data);
    });
  }

  // ── Acciones de partida (Cloud Functions) ─────────────────────────────────

  @override
  Future<void> iniciarRonda({required String roomId}) async {
    try {
      await _functions
          .httpsCallable('startRound')
          .call<void>({'roomId': roomId});
      await _telemetria.evento('ronda_iniciada', params: {'sala_id': roomId});
    } on FirebaseFunctionsException catch (e) {
      await _telemetria.registrarError(e, null);
      throw Exception(_mensajeError(e.code, e.message));
    }
  }

  @override
  Future<void> accionJugador({
    required String roomId,
    required String accion,
    int? manoIdx,
  }) async {
    try {
      await _functions.httpsCallable('playerAction').call<void>({
        'roomId': roomId,
        'accion': accion,
        if (manoIdx != null) 'manoIdx': manoIdx,
      });
      await _telemetria.evento(
        'accion_jugador',
        params: {
          'accion': accion,
          'sala_id': roomId,
        },
      );
    } on FirebaseFunctionsException catch (e) {
      await _telemetria.registrarError(e, null);
      throw Exception(_mensajeError(e.code, e.message));
    }
  }

  // ── Estado de partida ─────────────────────────────────────────────────────

  @override
  Stream<EstadoPartida?> partidaStream(String gameId) {
    return _db.collection('games').doc(gameId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return EstadoPartida.fromDoc(snap.id, snap.data()!);
    });
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  String _generarCodigo() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  int _proximoAsiento(List<JugadorEnSala> jugadores) {
    final asientos =
        jugadores.where((j) => !j.isSpectator).map((j) => j.seat).toSet();
    for (var i = 0; i < 6; i++) {
      if (!asientos.contains(i)) return i;
    }
    // Invariante: unirseASala valida estaLlena antes; si llega aquí, es un bug.
    throw StateError('No hay asientos libres en la sala.');
  }

  String _mensajeError(String? code, String? message) => switch (code) {
        'not-found' => 'Sala o partida no encontrada.',
        'failed-precondition' => message ?? 'Condición inválida.',
        'permission-denied' => 'No tienes permiso para esta acción.',
        'invalid-argument' => message ?? 'Argumento inválido.',
        _ => 'Error: ${message ?? code ?? 'desconocido'}',
      };
}
