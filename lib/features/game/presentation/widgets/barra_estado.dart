// ============================================================
//  Barra superior: datos del juego (banca, en juego, conteo) y
//  el botón que abre el menú lateral (issue #67).
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/temas.dart';
import '../../../../core/utils/formato.dart';
import '../controlador_juego.dart';

/// Cabecera con la banca, lo apostado y el conteo (si está activo), más el
/// acceso al menú lateral. La navegación a perfil/misiones/ranking/etc. y el
/// tema viven ahora en el [MenuDrawer], no en esta barra.
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
        ),
      ),
    );
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
          IconButton(
            tooltip: 'Menú',
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ],
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
