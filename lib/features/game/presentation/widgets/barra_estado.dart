// ============================================================
//  Barra superior: dinero, info del shoe, tema y ajustes
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/tema_provider.dart';
import '../../../../core/theme/temas.dart';
import '../../../../core/utils/formato.dart';
import '../controlador_juego.dart';
import '../estado_juego.dart';
import 'panel_ajustes.dart';

/// Cabecera con la banca, lo apostado, el conteo (si está activo) y los
/// selectores de tema y ajustes.
class BarraEstado extends ConsumerWidget {
  const BarraEstado({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Solo reconstruye cuando cambian los datos de la barra, no en cada carta.
    final datos = ref.watch(
      controladorJuegoProvider.select(
        (e) => (
          banca: e.banca,
          enJuego: e.totalEnJuego,
          mostrarConteo: e.config.mostrarConteo,
          conteoCorrido: e.conteoCorrido,
          conteoVerdadero: e.conteoVerdadero,
          enRonda: e.fase == FaseJuego.jugando || e.fase == FaseJuego.seguro,
        ),
      ),
    );
    final temaActual = ref.watch(temaProvider);
    final acento = context.tapete.acento;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _Dato(etiqueta: 'Banca', valor: dinero(datos.banca), acento: acento),
          const SizedBox(width: 16),
          _Dato(etiqueta: 'En juego', valor: dinero(datos.enJuego)),
          if (datos.mostrarConteo) ...[
            const SizedBox(width: 16),
            _Dato(
              etiqueta: 'Conteo',
              valor:
                  '${datos.conteoCorrido} (${datos.conteoVerdadero.toStringAsFixed(1)})',
            ),
          ],
          const Spacer(),
          // Selector de tema.
          PopupMenuButton<TemaApp>(
            tooltip: 'Tema',
            initialValue: temaActual,
            onSelected: (t) => ref.read(temaProvider.notifier).seleccionar(t),
            itemBuilder: (context) => [
              for (final t in TemaApp.values)
                PopupMenuItem<TemaApp>(
                  value: t,
                  child: Text('${t.icono}  ${t.nombre}'),
                ),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(temaActual.icono, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, color: Colors.white),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Multijugador',
            icon: const Icon(Icons.groups, color: Colors.white),
            onPressed: () => context.push('/lobby'),
          ),
          IconButton(
            tooltip: 'Amigos',
            icon: const Icon(Icons.people, color: Colors.white),
            onPressed: () => context.push('/friends'),
          ),
          IconButton(
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () => _abrirAjustes(context, ref),
          ),
        ],
      ),
    );
  }

  void _abrirAjustes(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(controladorJuegoProvider.notifier);
    final configActual = ref.read(controladorJuegoProvider).config;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => PanelAjustes(
        config: configActual,
        onGuardar: ctrl.aplicarConfig,
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final Color? acento;

  const _Dato({required this.etiqueta, required this.valor, this.acento});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          etiqueta,
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
        Text(
          valor,
          style: TextStyle(
            color: acento ?? Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
