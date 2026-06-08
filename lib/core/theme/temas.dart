// ============================================================
//  Temas de la app (4 paletas migradas del juego web original)
//
//  Cada tema define un `ColorScheme` de Material 3 más una
//  extensión [ColoresTapete] con los colores del fieltro de la
//  mesa y el color de acento, que los widgets del tapete pintan
//  como degradado. Equivale a las variables CSS `--tapete1`,
//  `--tapete2` y `--acento` del legacy (`styles.css`).
// ============================================================

import 'package:flutter/material.dart';

/// Los 4 temas disponibles, con su nombre e ícono para el selector.
enum TemaApp {
  clasico('Clásico', '🟢'),
  noche('Noche', '🔵'),
  rubi('Rubí', '🔴'),
  oscuro('Oscuro', '⚫');

  /// Nombre legible para el selector de temas.
  final String nombre;

  /// Emoji que representa el tema en el selector.
  final String icono;

  const TemaApp(this.nombre, this.icono);
}

/// Colores propios del tapete de la mesa, fuera del `ColorScheme` estándar.
///
/// Se exponen como [ThemeExtension] para que cualquier widget los lea con
/// `Theme.of(context).extension<ColoresTapete>()` y se interpolen al cambiar
/// de tema.
@immutable
class ColoresTapete extends ThemeExtension<ColoresTapete> {
  /// Color superior/central del degradado del fieltro.
  final Color tapete1;

  /// Color inferior/exterior del degradado del fieltro.
  final Color tapete2;

  /// Color de acento (botones primarios, resaltes, fichas).
  final Color acento;

  const ColoresTapete({
    required this.tapete1,
    required this.tapete2,
    required this.acento,
  });

  @override
  ColoresTapete copyWith({Color? tapete1, Color? tapete2, Color? acento}) {
    return ColoresTapete(
      tapete1: tapete1 ?? this.tapete1,
      tapete2: tapete2 ?? this.tapete2,
      acento: acento ?? this.acento,
    );
  }

  @override
  ColoresTapete lerp(ThemeExtension<ColoresTapete>? other, double t) {
    if (other is! ColoresTapete) return this;
    return ColoresTapete(
      tapete1: Color.lerp(tapete1, other.tapete1, t)!,
      tapete2: Color.lerp(tapete2, other.tapete2, t)!,
      acento: Color.lerp(acento, other.acento, t)!,
    );
  }
}

/// Construye el [ThemeData] completo para un [TemaApp] dado.
ThemeData construirTema(TemaApp tema) {
  final ({Color tapete1, Color tapete2, Color acento}) p = switch (tema) {
    TemaApp.clasico => (
        tapete1: const Color(0xFF0B6B3A),
        tapete2: const Color(0xFF064023),
        acento: const Color(0xFFFFD166),
      ),
    TemaApp.noche => (
        tapete1: const Color(0xFF1E3C72),
        tapete2: const Color(0xFF0A1530),
        acento: const Color(0xFF4ECDC4),
      ),
    TemaApp.rubi => (
        tapete1: const Color(0xFF8E1D1D),
        tapete2: const Color(0xFF3A0808),
        acento: const Color(0xFFFFD166),
      ),
    TemaApp.oscuro => (
        tapete1: const Color(0xFF2C2C34),
        tapete2: const Color(0xFF0E0E12),
        acento: const Color(0xFFF1C40F),
      ),
  };

  final colorScheme = ColorScheme.fromSeed(
    seedColor: p.acento,
    brightness: Brightness.dark,
    primary: p.acento,
    surface: p.tapete2,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: p.tapete2,
    fontFamily: 'Segoe UI',
    extensions: [
      ColoresTapete(tapete1: p.tapete1, tapete2: p.tapete2, acento: p.acento),
    ],
  );
}

/// Atajo para leer los [ColoresTapete] del tema actual sin verificar null.
extension ColoresTapeteContext on BuildContext {
  ColoresTapete get tapete => Theme.of(this).extension<ColoresTapete>()!;
}
