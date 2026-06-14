// ============================================================
//  Menú lateral (Drawer) de navegación principal.
//
//  Agrupa el acceso a perfil, progresión, social, tema y ajustes.
//  Vive en la pantalla del juego (la home), que es donde se monta
//  el Scaffold con drawer.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/tema_provider.dart';
import '../../../../core/theme/temas.dart';
import '../../../../core/utils/formato.dart';
import '../../../../core/widgets/avatar.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../wallet/presentation/wallet_provider.dart';
import '../controlador_juego.dart';
import 'panel_ajustes.dart';

class MenuDrawer extends ConsumerWidget {
  const MenuDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(perfilStreamProvider).valueOrNull;
    final saldo = ref.watch(saldoProvider).valueOrNull ?? perfil?.balance ?? 0;
    final temaActual = ref.watch(temaProvider);
    final avatar = perfil?.avatar ?? '🃏';

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(perfil?.displayName ?? 'Jugador'),
            accountEmail: Text('Saldo: ${dinero(saldo)}'),
            currentAccountPicture: CircleAvatar(
              backgroundImage:
                  avatarEsUrl(avatar) ? NetworkImage(avatar) : null,
              child: avatarEsUrl(avatar)
                  ? null
                  : Text(avatar, style: const TextStyle(fontSize: 28)),
            ),
          ),
          _item(context, Icons.account_circle, 'Mi perfil', '/perfil'),
          _item(context, Icons.checklist, 'Misiones', '/misiones'),
          _item(context, Icons.card_giftcard, 'Bono diario', '/bono'),
          _item(context, Icons.leaderboard, 'Ranking', '/leaderboard'),
          const Divider(),
          _item(context, Icons.groups, 'Multijugador', '/lobby'),
          _item(context, Icons.people, 'Amigos', '/friends'),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('Tema'),
            subtitle: Text('${temaActual.icono}  ${temaActual.nombre}'),
            onTap: () => _elegirTema(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Reglas de la mesa'),
            onTap: () => _abrirAjustes(context, ref),
          ),
        ],
      ),
    );
  }

  /// Item de navegación: cierra el drawer y empuja la ruta.
  Widget _item(
    BuildContext context,
    IconData icono,
    String texto,
    String ruta,
  ) {
    return ListTile(
      leading: Icon(icono),
      title: Text(texto),
      onTap: () {
        Navigator.of(context).pop(); // cierra el drawer
        context.push(ruta);
      },
    );
  }

  Future<void> _elegirTema(BuildContext context, WidgetRef ref) async {
    final actual = ref.read(temaProvider);
    final elegido = await showDialog<TemaApp>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Elige un tema'),
        children: [
          for (final t in TemaApp.values)
            ListTile(
              leading: Text(t.icono, style: const TextStyle(fontSize: 20)),
              title: Text(t.nombre),
              trailing: t == actual ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(ctx).pop(t),
            ),
        ],
      ),
    );
    if (elegido != null && context.mounted) {
      ref.read(temaProvider.notifier).seleccionar(elegido);
    }
  }

  void _abrirAjustes(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(controladorJuegoProvider.notifier);
    final configActual = ref.read(controladorJuegoProvider).config;
    // Capturamos el contexto del Scaffold (fuera del drawer) ANTES del pop:
    // tras cerrarlo, el contexto del MenuDrawer queda desmontado y no sirve.
    final scaffoldContext = Scaffold.of(context).context;
    Navigator.of(context).pop(); // cierra el drawer
    showModalBottomSheet<void>(
      context: scaffoldContext,
      isScrollControlled: true,
      backgroundColor: Theme.of(scaffoldContext).colorScheme.surface,
      builder: (_) => PanelAjustes(
        config: configActual,
        onGuardar: ctrl.aplicarConfig,
      ),
    );
  }
}
