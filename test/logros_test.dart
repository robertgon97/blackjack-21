// Tests del catálogo de logros (profile/domain/logros.dart): integridad del
// catálogo y búsqueda por id. La metadata debe mantenerse en paridad con los
// ids evaluados en functions/src/logros.ts.

import 'package:blackjack_21/features/profile/domain/logros.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('catalogoLogros', () {
    test('no está vacío', () {
      expect(catalogoLogros, isNotEmpty);
    });

    test('los ids son únicos', () {
      final ids = catalogoLogros.map((l) => l.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test(
        'incluye exactamente los ids evaluados server-side (paridad con logros.ts)',
        () {
      final ids = catalogoLogros.map((l) => l.id).toSet();
      expect(ids, {
        'primera',
        'bj',
        'racha3',
        'racha5',
        'veterano',
        'centenario',
        'granGanancia',
        'ricachon',
      });
    });

    test('cada logro tiene nombre, emoji y descripción no vacíos', () {
      for (final l in catalogoLogros) {
        expect(l.nombre, isNotEmpty, reason: 'nombre de ${l.id}');
        expect(l.emoji, isNotEmpty, reason: 'emoji de ${l.id}');
        expect(l.descripcion, isNotEmpty, reason: 'descripción de ${l.id}');
      }
    });
  });

  group('logroPorId', () {
    test('devuelve el logro cuando existe', () {
      expect(logroPorId('bj')?.nombre, '¡Blackjack!');
    });

    test('devuelve null para un id desconocido', () {
      expect(logroPorId('inexistente'), isNull);
    });
  });
}
