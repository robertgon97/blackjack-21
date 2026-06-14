import 'package:cloud_functions/cloud_functions.dart';

import '../domain/i_resultado_solo_repository.dart';
import '../domain/modelos.dart';

/// Implementación de [IResultadoSoloRepository] vía la Cloud Function
/// `resolveSoloRound` (región `southamerica-east1`).
class CloudResultadoSoloRepository implements IResultadoSoloRepository {
  CloudResultadoSoloRepository({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'southamerica-east1');

  final FirebaseFunctions _functions;

  @override
  Future<int> registrarRonda({
    required List<Mano> manos,
    required List<Carta> manoCrupier,
    required int seguro,
    required ConfigJuego config,
  }) async {
    // Solo se envía el `valor` de cada carta: el palo no afecta el cómputo y
    // así el payload es mínimo.
    final payload = <String, dynamic>{
      'manos': [
        for (final m in manos)
          {
            'cartas': [
              for (final c in m.cartas) {'valor': c.valor},
            ],
            'apuesta': m.apuesta,
            'rendida': m.rendida,
          },
      ],
      'manoCrupier': [
        for (final c in manoCrupier) {'valor': c.valor},
      ],
      'seguro': seguro,
      'config': {
        'pagoBlackjack': config.pagoBlackjack,
        'empujeEn22': config.empujeEn22,
        'h17': config.crupierPideEn17Suave,
      },
    };

    try {
      final res = await _functions
          .httpsCallable('resolveSoloRound')
          .call<Object?>(payload);
      final data = res.data as Map<Object?, Object?>;
      return (data['balance'] as num).toInt();
    } on FirebaseFunctionsException catch (e) {
      throw Exception(_mensaje(e.code, e.message));
    }
  }

  String _mensaje(String code, String? msg) => switch (code) {
        'unauthenticated' => 'Inicia sesión para guardar tu saldo.',
        'failed-precondition' =>
          msg ?? 'No se pudo validar la ronda en el servidor.',
        'invalid-argument' => 'Datos de la ronda inválidos.',
        'not-found' => 'No se encontró tu perfil.',
        _ => 'No se pudo guardar el saldo. Intenta de nuevo.',
      };
}
