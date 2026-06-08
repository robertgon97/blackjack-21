// ============================================================
//  Botones de acción del turno del jugador
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/temas.dart';
import '../controlador_juego.dart';

/// Pedir / Plantarse / Doblar / Dividir / Rendirse, según lo permitido.
class BotonesAccion extends ConsumerWidget {
  const BotonesAccion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Solo reconstruye cuando cambian las opciones de la mano, no en cada carta.
    final v = ref.watch(
      controladorJuegoProvider.select((e) {
        final opc = e.opcionesActivas;
        return (
          libre: !e.animando,
          puedeDoblar: opc.puedeDoblar,
          puedeDividir: opc.puedeDividir,
          puedeRendirse: opc.puedeRendirse,
          permitirRendirse: e.config.permitirRendirse,
        );
      }),
    );
    final ctrl = ref.read(controladorJuegoProvider.notifier);
    final libre = v.libre;
    final acento = context.tapete.acento;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        _BotonAccion(
          texto: 'PEDIR',
          icono: Icons.add,
          color: acento,
          onTap: libre ? () => unawaited(ctrl.pedir()) : null,
        ),
        _BotonAccion(
          texto: 'PLANTARSE',
          icono: Icons.pan_tool,
          color: acento,
          onTap: libre ? () => unawaited(ctrl.plantarse()) : null,
        ),
        _BotonAccion(
          texto: 'DOBLAR',
          icono: Icons.exposure_plus_2,
          color: acento,
          onTap: libre && v.puedeDoblar ? () => unawaited(ctrl.doblar()) : null,
        ),
        _BotonAccion(
          texto: 'DIVIDIR',
          icono: Icons.call_split,
          color: acento,
          onTap:
              libre && v.puedeDividir ? () => unawaited(ctrl.dividir()) : null,
        ),
        if (v.permitirRendirse)
          _BotonAccion(
            texto: 'RENDIRSE',
            icono: Icons.flag,
            color: acento,
            onTap: libre && v.puedeRendirse
                ? () => unawaited(ctrl.rendirse())
                : null,
          ),
      ],
    );
  }
}

class _BotonAccion extends StatelessWidget {
  final String texto;
  final IconData icono;
  final Color color;
  final VoidCallback? onTap;

  const _BotonAccion({
    required this.texto,
    required this.icono,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final habilitado = onTap != null;
    return FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: habilitado ? color : Colors.white12,
        foregroundColor: habilitado ? Colors.black : Colors.white38,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
      icon: Icon(icono, size: 18),
      label: Text(texto),
    );
  }
}
