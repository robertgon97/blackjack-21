import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/telemetria/telemetria_provider.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/firestore_sala_repository.dart';
import '../domain/i_sala_repository.dart';
import '../domain/modelos.dart';

final salaRepositoryProvider = Provider<ISalaRepository>((ref) {
  return FirestoreSalaRepository(
    telemetria: ref.read(servicioTelemetriaProvider),
  );
});

/// Stream de salas públicas para el lobby.
final salasPublicasProvider = StreamProvider<List<Sala>>((ref) {
  return ref.watch(salaRepositoryProvider).salasPublicasStream();
});

/// Stream de una sala específica por ID.
final salaProvider = StreamProvider.family<Sala?, String>((ref, roomId) {
  return ref.watch(salaRepositoryProvider).salaStream(roomId);
});

/// Stream de la partida en curso para un gameId dado.
final partidaProvider =
    StreamProvider.family<EstadoPartida?, String>((ref, gameId) {
  return ref.watch(salaRepositoryProvider).partidaStream(gameId);
});

/// Acciones disponibles para la sala. Separa la lógica de negocio de la UI.
final salaActionsProvider = Provider.family<SalaActions, String>(
  (ref, roomId) => SalaActions(ref, roomId),
);

class SalaActions {
  SalaActions(this._ref, this._roomId);

  final Ref _ref;
  final String _roomId;

  ISalaRepository get _repo => _ref.read(salaRepositoryProvider);

  Future<void> unirse({required bool comoEspectador}) async {
    final perfil = _ref.read(perfilStreamProvider).valueOrNull;
    if (perfil == null) return;
    await _repo.unirseASala(
      roomId: _roomId,
      uid: perfil.uid,
      displayName: perfil.displayName,
      avatar: perfil.avatar,
      balance: perfil.balance,
      comoEspectador: comoEspectador,
    );
  }

  Future<void> salir() async {
    final perfil = _ref.read(perfilStreamProvider).valueOrNull;
    if (perfil == null) return;
    await _repo.salirDeSala(roomId: _roomId, uid: perfil.uid);
  }

  Future<void> establecerApuesta(int apuesta) async {
    final perfil = _ref.read(perfilStreamProvider).valueOrNull;
    if (perfil == null) return;
    await _repo.establecerApuesta(
      roomId: _roomId,
      uid: perfil.uid,
      apuesta: apuesta,
    );
  }

  Future<void> marcarListo(bool listo) async {
    final perfil = _ref.read(perfilStreamProvider).valueOrNull;
    if (perfil == null) return;
    await _repo.marcarListo(roomId: _roomId, uid: perfil.uid, listo: listo);
  }

  Future<void> cambiarEstado(EstadoSala estado) async {
    await _repo.cambiarEstadoSala(roomId: _roomId, nuevoEstado: estado);
  }

  Future<void> iniciarRonda() async {
    await _repo.iniciarRonda(roomId: _roomId);
  }

  Future<void> accion(String accion, {int? manoIdx}) async {
    await _repo.accionJugador(
      roomId: _roomId,
      accion: accion,
      manoIdx: manoIdx,
    );
  }
}
