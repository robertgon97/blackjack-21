// Tests del dominio de misiones (misiones/domain): catálogo, parsing del
// progreso y derivación del estado. Lógica pura.

import 'package:blackjack_21/features/misiones/domain/mision.dart';
import 'package:blackjack_21/features/misiones/domain/progreso_periodo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('catalogoMisiones', () {
    test('los ids son únicos', () {
      final ids = catalogoMisiones.map((m) => m.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('incluye los ids del catálogo server-side (paridad con misiones.ts)',
        () {
      final ids = catalogoMisiones.map((m) => m.id).toSet();
      expect(ids, {
        'd_jugar',
        'd_ganar',
        'd_blackjack',
        's_jugar',
        's_ganar',
        's_ganancia',
      });
    });

    test('hay misiones diarias y semanales', () {
      expect(catalogoMisiones.any((m) => m.tipo == TipoMision.diaria), isTrue);
      expect(catalogoMisiones.any((m) => m.tipo == TipoMision.semanal), isTrue);
    });
  });

  group('ProgresoPeriodo.fromMap', () {
    test('mapa nulo da progreso vacío', () {
      final p = ProgresoPeriodo.fromMap(null);
      expect(p.contadores.values.every((v) => v == 0), isTrue);
      expect(p.reclamadas, isEmpty);
    });

    test('lee contadores y reclamadas', () {
      final p = ProgresoPeriodo.fromMap({
        'manosJugadas': 7,
        'ganadas': 4,
        'reclamadas': ['d_jugar'],
      });
      expect(p.contadores['manosJugadas'], 7);
      expect(p.contadores['ganadas'], 4);
      expect(p.contadores['blackjacks'], 0);
      expect(p.reclamadas, {'d_jugar'});
    });
  });

  group('EstadoMision.desde', () {
    const mision = Mision(
      id: 'd_ganar',
      tipo: TipoMision.diaria,
      metrica: MetricaMision.ganadas,
      meta: 3,
      recompensa: 150,
      descripcion: 'Gana 3 manos hoy',
    );

    test('completada y no reclamada → reclamable', () {
      final p = ProgresoPeriodo.fromMap({'ganadas': 3});
      final e = EstadoMision.desde(mision, p);
      expect(e.completada, isTrue);
      expect(e.reclamada, isFalse);
      expect(e.reclamable, isTrue);
      expect(e.fraccion, 1.0);
    });

    test('en progreso → no reclamable', () {
      final e =
          EstadoMision.desde(mision, ProgresoPeriodo.fromMap({'ganadas': 1}));
      expect(e.completada, isFalse);
      expect(e.reclamable, isFalse);
      expect(e.fraccion, closeTo(1 / 3, 1e-9));
    });

    test('ya reclamada → no reclamable aunque esté completada', () {
      final p = ProgresoPeriodo.fromMap({
        'ganadas': 5,
        'reclamadas': ['d_ganar'],
      });
      final e = EstadoMision.desde(mision, p);
      expect(e.completada, isTrue);
      expect(e.reclamada, isTrue);
      expect(e.reclamable, isFalse);
    });
  });
}
