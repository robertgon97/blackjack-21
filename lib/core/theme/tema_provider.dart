// ============================================================
//  Provider del tema activo de la app
//
//  Mantiene cuál de los 4 [TemaApp] está seleccionado. La raíz
//  (`app.dart`) lo observa para reconstruir el MaterialApp.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'temas.dart';

/// Provider del tema seleccionado (por defecto, el clásico verde).
final temaProvider = NotifierProvider<TemaNotifier, TemaApp>(TemaNotifier.new);

class TemaNotifier extends Notifier<TemaApp> {
  @override
  TemaApp build() => TemaApp.clasico;

  /// Cambia el tema activo.
  void seleccionar(TemaApp tema) => state = tema;
}
