import 'modelos.dart';

/// Contrato del módulo de salas multijugador.
/// La capa data implementa esta interfaz; la presentación la conoce via providers.
abstract interface class ISalaRepository {
  // ── Lobby ────────────────────────────────────────────────────────────────

  /// Stream de salas públicas activas (waiting o betting), más recientes primero.
  Stream<List<Sala>> salasPublicasStream();

  // ── Sala individual ───────────────────────────────────────────────────────

  /// Stream del documento de sala. Emite null si la sala no existe.
  Stream<Sala?> salaStream(String roomId);

  /// Busca una sala por su código de invitación. Retorna null si no existe.
  Future<Sala?> buscarPorCodigo(String inviteCode);

  // ── Acciones de creación / entrada / salida ───────────────────────────────

  /// Crea una sala nueva y devuelve su ID.
  Future<String> crearSala({
    required String hostUid,
    required String hostName,
    required String hostAvatar,
    required int hostBalance,
    required String nombre,
    required int maxJugadores,
    required bool privada,
    required ConfigSala config,
  });

  /// Añade al usuario como jugador (o espectador) en la sala.
  Future<void> unirseASala({
    required String roomId,
    required String uid,
    required String displayName,
    required String avatar,
    required int balance,
    required bool comoEspectador,
  });

  /// Elimina al usuario de los players de la sala.
  Future<void> salirDeSala({required String roomId, required String uid});

  // ── Apuestas ─────────────────────────────────────────────────────────────

  /// Actualiza la apuesta del jugador en la sala.
  Future<void> establecerApuesta({
    required String roomId,
    required String uid,
    required int apuesta,
  });

  /// Marca al jugador como listo (o no listo) para iniciar la ronda.
  Future<void> marcarListo({
    required String roomId,
    required String uid,
    required bool listo,
  });

  // ── Acciones del host ─────────────────────────────────────────────────────

  /// Cambia el estado de la sala (p. ej. waiting → betting, finished → betting).
  Future<void> cambiarEstadoSala({
    required String roomId,
    required EstadoSala nuevoEstado,
  });

  // ── Acciones de partida (Cloud Functions) ─────────────────────────────────

  /// Inicia la ronda: baraja, reparte y actualiza la sala a 'playing'.
  Future<void> iniciarRonda({required String roomId});

  /// Aplica una acción del jugador a su mano actual.
  /// [accion]: 'pedir' | 'plantarse' | 'doblar' | 'rendirse' | 'dividir'
  Future<void> accionJugador({
    required String roomId,
    required String accion,
    int? manoIdx,
  });

  // ── Estado de partida ─────────────────────────────────────────────────────

  /// Stream de la partida en curso (games/{gameId}). Emite null si no hay.
  Stream<EstadoPartida?> partidaStream(String gameId);
}
