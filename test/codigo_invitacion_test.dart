// Tests de la normalización del código de invitación (friends/domain): tolera el
// formato que teclea el usuario (sin guion, minúsculas, espacios).

import 'package:blackjack_21/features/friends/domain/codigo_invitacion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizarCodigoInvitacion', () {
    test('el formato canónico se mantiene', () {
      expect(normalizarCodigoInvitacion('BJ-AB12'), 'BJ-AB12');
    });

    test('reinserta el guion si falta', () {
      expect(normalizarCodigoInvitacion('BJAB12'), 'BJ-AB12');
    });

    test('tolera minúsculas, espacios y guion ausente', () {
      expect(normalizarCodigoInvitacion('bjab12'), 'BJ-AB12');
      expect(normalizarCodigoInvitacion('bj-ab12'), 'BJ-AB12');
      expect(normalizarCodigoInvitacion('  BJ AB12 '), 'BJ-AB12');
    });

    test('cadena vacía queda vacía', () {
      expect(normalizarCodigoInvitacion(''), '');
      expect(normalizarCodigoInvitacion('   '), '');
    });

    test('entrada que no es un código BJ no se fuerza al formato', () {
      // No empieza por BJ → solo se limpia (no coincidirá con ningún código).
      expect(normalizarCodigoInvitacion('ABCD'), 'ABCD');
    });

    test('solo el prefijo "BJ" no se completa (queda corto)', () {
      // < 7 chars: buscarPorCodigo lo descarta sin leer Firestore.
      expect(normalizarCodigoInvitacion('BJ'), 'BJ');
      expect(normalizarCodigoInvitacion('BJ').length, lessThan(7));
    });
  });
}
