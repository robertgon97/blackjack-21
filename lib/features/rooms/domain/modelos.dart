// ============================================================
//  Modelos de dominio — Salas multijugador
//
//  Sin dependencias de Flutter ni Firebase.
//  Reglas de negocio: docs/reglas-negocio/salas-y-multijugador.md
//  Modelo de datos: docs/arquitectura/modelo-datos.md
// ============================================================

import '../../game/domain/modelos.dart';

/// Estado del ciclo de vida de una sala.
enum EstadoSala { waiting, betting, playing, finished }

extension EstadoSalaX on EstadoSala {
  String get etiqueta => switch (this) {
        EstadoSala.waiting => 'Esperando',
        EstadoSala.betting => 'Apostando',
        EstadoSala.playing => 'Jugando',
        EstadoSala.finished => 'Finalizada',
      };

  static EstadoSala fromString(String s) => switch (s) {
        'betting' => EstadoSala.betting,
        'playing' => EstadoSala.playing,
        'finished' => EstadoSala.finished,
        _ => EstadoSala.waiting,
      };
}

/// Configuración de la sala: reglas del juego + opciones de mesa.
class ConfigSala {
  final ConfigJuego configJuego;
  final bool turnosSimultaneos;
  final int timerSeg;
  final bool commsHabilitado;

  const ConfigSala({
    this.configJuego = const ConfigJuego(),
    this.turnosSimultaneos = true,
    this.timerSeg = 45,
    this.commsHabilitado = false,
  });

  ConfigSala copyWith({
    ConfigJuego? configJuego,
    bool? turnosSimultaneos,
    int? timerSeg,
    bool? commsHabilitado,
  }) {
    return ConfigSala(
      configJuego: configJuego ?? this.configJuego,
      turnosSimultaneos: turnosSimultaneos ?? this.turnosSimultaneos,
      timerSeg: timerSeg ?? this.timerSeg,
      commsHabilitado: commsHabilitado ?? this.commsHabilitado,
    );
  }

  Map<String, dynamic> toMap() => {
        'numBarajas': configJuego.numBarajas,
        'pagoBlackjack': configJuego.pagoBlackjack,
        'crupierPideEn17Suave': configJuego.crupierPideEn17Suave,
        'empujeEn22': configJuego.empujeEn22,
        'apuestaMin': configJuego.apuestaMin,
        'apuestaMax': configJuego.apuestaMax,
        'permitirRendirse': configJuego.permitirRendirse,
        'turnosSimultaneos': turnosSimultaneos,
        'timerSeg': timerSeg,
        'commsHabilitado': commsHabilitado,
      };

  factory ConfigSala.fromMap(Map<String, dynamic> m) {
    return ConfigSala(
      configJuego: ConfigJuego(
        numBarajas: m['numBarajas'] as int? ?? 6,
        pagoBlackjack: (m['pagoBlackjack'] as num?)?.toDouble() ?? 1.5,
        crupierPideEn17Suave: m['crupierPideEn17Suave'] as bool? ?? false,
        empujeEn22: m['empujeEn22'] as bool? ?? false,
        apuestaMin: m['apuestaMin'] as int? ?? 10,
        apuestaMax: m['apuestaMax'] as int? ?? 500,
        permitirRendirse: m['permitirRendirse'] as bool? ?? true,
      ),
      turnosSimultaneos: m['turnosSimultaneos'] as bool? ?? true,
      timerSeg: m['timerSeg'] as int? ?? 45,
      commsHabilitado: m['commsHabilitado'] as bool? ?? false,
    );
  }
}

/// Snapshot de un jugador dentro de `rooms/{id}/players`.
class JugadorEnSala {
  final String uid;
  final String displayName;
  final String avatar;
  final int balance;
  final int? apuesta;
  final bool ready;
  final bool connected;
  final int seat;
  final bool isSpectator;

  const JugadorEnSala({
    required this.uid,
    required this.displayName,
    required this.avatar,
    required this.balance,
    this.apuesta,
    this.ready = false,
    this.connected = true,
    required this.seat,
    this.isSpectator = false,
  });

  JugadorEnSala copyWith({
    String? displayName,
    String? avatar,
    int? balance,
    int? apuesta,
    bool clearApuesta = false,
    bool? ready,
    bool? connected,
    int? seat,
    bool? isSpectator,
  }) {
    return JugadorEnSala(
      uid: uid,
      displayName: displayName ?? this.displayName,
      avatar: avatar ?? this.avatar,
      balance: balance ?? this.balance,
      apuesta: clearApuesta ? null : (apuesta ?? this.apuesta),
      ready: ready ?? this.ready,
      connected: connected ?? this.connected,
      seat: seat ?? this.seat,
      isSpectator: isSpectator ?? this.isSpectator,
    );
  }

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'avatar': avatar,
        'balance': balance,
        if (apuesta != null) 'apuesta': apuesta,
        'ready': ready,
        'connected': connected,
        'seat': seat,
        'isSpectator': isSpectator,
      };

  factory JugadorEnSala.fromMap(String uid, Map<String, dynamic> m) {
    return JugadorEnSala(
      uid: uid,
      displayName: m['displayName'] as String? ?? 'Jugador',
      avatar: m['avatar'] as String? ?? '🃏',
      balance: m['balance'] as int? ?? 0,
      apuesta: m['apuesta'] as int?,
      ready: m['ready'] as bool? ?? false,
      connected: m['connected'] as bool? ?? true,
      seat: m['seat'] as int? ?? 0,
      isSpectator: m['isSpectator'] as bool? ?? false,
    );
  }
}

/// Snapshot de una sala multijugador (documento `rooms/{id}`).
class Sala {
  final String id;
  final String hostUid;
  final String hostName;
  final String name;
  final EstadoSala status;
  final int maxPlayers;
  final bool private;
  final String inviteCode;
  final ConfigSala config;
  final Map<String, JugadorEnSala> players;
  final String? currentGameId;
  final DateTime createdAt;

  const Sala({
    required this.id,
    required this.hostUid,
    required this.hostName,
    required this.name,
    required this.status,
    required this.maxPlayers,
    required this.private,
    required this.inviteCode,
    required this.config,
    required this.players,
    this.currentGameId,
    required this.createdAt,
  });

  /// Jugadores activos (no espectadores), ordenados por asiento.
  List<JugadorEnSala> get jugadoresActivos {
    final lista = players.values.where((j) => !j.isSpectator).toList();
    lista.sort((a, b) => a.seat.compareTo(b.seat));
    return lista;
  }

  bool get todosListos =>
      jugadoresActivos.isNotEmpty && jugadoresActivos.every((j) => j.ready);

  int get asientosLibres => maxPlayers - jugadoresActivos.length;

  bool get estaLlena => asientosLibres <= 0;

  factory Sala.fromDoc(String id, Map<String, dynamic> d) {
    final playersRaw = (d['players'] as Map<String, dynamic>?) ?? {};
    final players = playersRaw.map(
      (uid, datos) => MapEntry(
        uid,
        JugadorEnSala.fromMap(uid, datos as Map<String, dynamic>),
      ),
    );
    final configRaw = (d['config'] as Map<String, dynamic>?) ?? {};

    return Sala(
      id: id,
      hostUid: d['hostUid'] as String? ?? '',
      hostName: d['hostName'] as String? ?? 'Host',
      name: d['name'] as String? ?? 'Mesa',
      status: EstadoSalaX.fromString(d['status'] as String? ?? 'waiting'),
      maxPlayers: d['maxPlayers'] as int? ?? 6,
      private: d['private'] as bool? ?? false,
      inviteCode: d['inviteCode'] as String? ?? '',
      config: ConfigSala.fromMap(configRaw),
      players: players,
      currentGameId: d['currentGameId'] as String?,
      createdAt: (d['createdAt'] as dynamic)?.toDate() as DateTime? ??
          DateTime.now(),
    );
  }
}

// ── Estado de la partida en curso (leído de games/{gameId}) ───────────────

/// Una mano de un jugador en el contexto multijugador.
class ManoPartida {
  final List<Carta> cartas;
  final int apuesta;
  final bool doblada;
  final bool rendida;
  final bool asPartido;

  const ManoPartida({
    required this.cartas,
    required this.apuesta,
    this.doblada = false,
    this.rendida = false,
    this.asPartido = false,
  });

  factory ManoPartida.fromMap(Map<String, dynamic> m) {
    return ManoPartida(
      cartas: (m['cartas'] as List<dynamic>? ?? [])
          .map((c) => _cartaFromMap(c as Map<String, dynamic>))
          .toList(),
      apuesta: m['apuesta'] as int? ?? 0,
      doblada: m['doblada'] as bool? ?? false,
      rendida: m['rendida'] as bool? ?? false,
      asPartido: m['asPartido'] as bool? ?? false,
    );
  }
}

Carta _cartaFromMap(Map<String, dynamic> m) {
  final paloStr = m['palo'] as String? ?? 'picas';
  final palo = Palo.values.firstWhere(
    (p) => p.name == paloStr,
    orElse: () => Palo.picas,
  );
  return Carta(palo, m['valor'] as String? ?? 'A');
}

/// Datos de un jugador dentro del documento `games/{id}`.
class DatosJugadorPartida {
  final List<ManoPartida> manos;
  final int indiceMano;
  final bool done;
  final String? result;

  const DatosJugadorPartida({
    required this.manos,
    this.indiceMano = 0,
    this.done = false,
    this.result,
  });

  factory DatosJugadorPartida.fromMap(Map<String, dynamic> m) {
    return DatosJugadorPartida(
      manos: (m['manos'] as List<dynamic>? ?? [])
          .map((x) => ManoPartida.fromMap(x as Map<String, dynamic>))
          .toList(),
      indiceMano: m['indiceMano'] as int? ?? 0,
      done: m['done'] as bool? ?? false,
      result: m['result'] as String?,
    );
  }
}

/// Snapshot de una partida en curso (documento `games/{id}`).
class EstadoPartida {
  final String id;
  final String roomId;
  final int round;
  final String phase;
  final List<Carta> dealerCards;
  final bool dealerHidden;
  final Map<String, DatosJugadorPartida> players;

  const EstadoPartida({
    required this.id,
    required this.roomId,
    required this.round,
    required this.phase,
    required this.dealerCards,
    required this.dealerHidden,
    required this.players,
  });

  factory EstadoPartida.fromDoc(String id, Map<String, dynamic> d) {
    final playersRaw = (d['players'] as Map<String, dynamic>?) ?? {};
    final players = playersRaw.map(
      (uid, datos) => MapEntry(
        uid,
        DatosJugadorPartida.fromMap(datos as Map<String, dynamic>),
      ),
    );
    return EstadoPartida(
      id: id,
      roomId: d['roomId'] as String? ?? '',
      round: d['round'] as int? ?? 1,
      phase: d['phase'] as String? ?? 'player_turns',
      dealerCards: (d['dealerCards'] as List<dynamic>? ?? [])
          .map((c) => _cartaFromMap(c as Map<String, dynamic>))
          .toList(),
      dealerHidden: d['dealerHidden'] as bool? ?? true,
      players: players,
    );
  }
}
