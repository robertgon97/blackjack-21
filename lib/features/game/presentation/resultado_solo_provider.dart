import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cloud_resultado_solo_repository.dart';
import '../domain/i_resultado_solo_repository.dart';

/// Repositorio que persiste el resultado de las rondas del juego solo vía la
/// Cloud Function `resolveSoloRound`.
final resultadoSoloRepositoryProvider = Provider<IResultadoSoloRepository>(
  (_) => CloudResultadoSoloRepository(),
);
