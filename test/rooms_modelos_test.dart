// Tests del dominio de salas (rooms): lógica observable de Sala y su parsing.
// Sin Firebase ni Flutter: solo modelos puros.

import 'package:blackjack_21/features/rooms/domain/modelos.dart';
import 'package:flutter_test/flutter_test.dart';

JugadorEnSala jugador({
  required String uid,
  required int seat,
  bool ready = false,
  bool espectador = false,
}) {
  return JugadorEnSala(
    uid: uid,
    displayName: uid,
    avatar: '🃏',
    balance: 1000,
    seat: seat,
    ready: ready,
    isSpectator: espectador,
  );
}

Sala sala({
  required Map<String, JugadorEnSala> players,
  int maxPlayers = 4,
  EstadoSala status = EstadoSala.waiting,
}) {
  return Sala(
    id: 'r1',
    hostUid: 'h',
    hostName: 'Host',
    name: 'Mesa',
    status: status,
    maxPlayers: maxPlayers,
    private: false,
    inviteCode: 'ABC123',
    config: const ConfigSala(),
    players: players,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  );
}

void main() {
  group('Sala.jugadoresActivos', () {
    test('excluye espectadores y ordena por asiento', () {
      final s = sala(
        players: {
          'b': jugador(uid: 'b', seat: 2),
          'a': jugador(uid: 'a', seat: 0),
          'esp': jugador(uid: 'esp', seat: -1, espectador: true),
          'c': jugador(uid: 'c', seat: 1),
        },
      );
      expect(
        s.jugadoresActivos.map((j) => j.uid).toList(),
        ['a', 'c', 'b'],
      );
    });
  });

  group('Sala.todosListos', () {
    test('false si no hay jugadores activos', () {
      final s = sala(players: {});
      expect(s.todosListos, isFalse);
    });

    test('false si algún activo no está listo', () {
      final s = sala(
        players: {
          'a': jugador(uid: 'a', seat: 0, ready: true),
          'b': jugador(uid: 'b', seat: 1, ready: false),
        },
      );
      expect(s.todosListos, isFalse);
    });

    test('true si todos los activos están listos', () {
      final s = sala(
        players: {
          'a': jugador(uid: 'a', seat: 0, ready: true),
          'b': jugador(uid: 'b', seat: 1, ready: true),
        },
      );
      expect(s.todosListos, isTrue);
    });

    test('ignora a los espectadores para el cómputo de listos', () {
      final s = sala(
        players: {
          'a': jugador(uid: 'a', seat: 0, ready: true),
          'esp': jugador(uid: 'esp', seat: -1, espectador: true),
        },
      );
      expect(s.todosListos, isTrue);
    });
  });

  group('Sala.asientosLibres / estaLlena', () {
    test('cuenta asientos según jugadores activos', () {
      final s = sala(
        maxPlayers: 4,
        players: {
          'a': jugador(uid: 'a', seat: 0),
          'esp': jugador(uid: 'esp', seat: -1, espectador: true),
        },
      );
      expect(s.asientosLibres, 3);
      expect(s.estaLlena, isFalse);
    });

    test('estaLlena cuando los activos igualan el máximo', () {
      final s = sala(
        maxPlayers: 2,
        players: {
          'a': jugador(uid: 'a', seat: 0),
          'b': jugador(uid: 'b', seat: 1),
        },
      );
      expect(s.asientosLibres, 0);
      expect(s.estaLlena, isTrue);
    });
  });

  group('Sala.fromDoc', () {
    test('parsea campos y jugadores', () {
      final s = Sala.fromDoc('doc1', {
        'hostUid': 'h',
        'hostName': 'Host',
        'name': 'Mesa VIP',
        'status': 'betting',
        'maxPlayers': 6,
        'private': true,
        'inviteCode': 'XYZ',
        'players': {
          'h': {
            'displayName': 'Host',
            'avatar': '🎩',
            'balance': 500,
            'seat': 0,
          },
        },
      });
      expect(s.id, 'doc1');
      expect(s.name, 'Mesa VIP');
      expect(s.status, EstadoSala.betting);
      expect(s.maxPlayers, 6);
      expect(s.private, isTrue);
      expect(s.players['h']?.balance, 500);
    });

    test('createdAt ausente usa el centinela epoch 0 (no la hora local)', () {
      final s = Sala.fromDoc('doc2', {'hostUid': 'h'});
      expect(s.createdAt, DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('status desconocido cae en waiting', () {
      final s = Sala.fromDoc('doc3', {'status': 'algo_raro'});
      expect(s.status, EstadoSala.waiting);
    });
  });
}
