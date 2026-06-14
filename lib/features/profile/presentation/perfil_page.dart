// ============================================================
//  Pantalla de perfil: cabecera editable, saldo, acceso al
//  historial, estadísticas (Fase 8) y progresión: nivel + logros (Fase 9).
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formato.dart';
import '../../auth/domain/perfil_usuario.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../wallet/presentation/wallet_provider.dart';
import '../domain/estadisticas.dart';
import '../domain/logros.dart';
import '../domain/niveles.dart';
import 'profile_provider.dart';

/// Emojis disponibles como avatar (el avatar se guarda como string).
const _avatares = [
  '🃏',
  '🎴',
  '♠️',
  '♥️',
  '♦️',
  '♣️',
  '🎰',
  '🤑',
  '😎',
  '🤠',
  '👑',
  '🦊',
];

class PerfilPage extends ConsumerWidget {
  const PerfilPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfilAsync = ref.watch(perfilStreamProvider);
    final statsAsync = ref.watch(estadisticasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: perfilAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('No se pudo cargar el perfil: $e')),
        data: (perfil) {
          if (perfil == null) {
            return const Center(child: Text('Sin sesión activa.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Cabecera(perfil: perfil),
              const SizedBox(height: 20),
              _TarjetaNivel(),
              const SizedBox(height: 20),
              _TarjetaSaldo(),
              const SizedBox(height: 20),
              Text(
                'Estadísticas',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              statsAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) =>
                    Text('No se pudieron cargar las estadísticas: $e'),
                data: (stats) => _GrillaEstadisticas(stats: stats),
              ),
              const SizedBox(height: 20),
              Text('Logros', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _GaleriaLogros(),
              if (perfil.isAnonymous) ...[
                const SizedBox(height: 20),
                _AvisoAnonimo(),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Cabecera con avatar, nombre, tipo de cuenta, código de invitación y
/// "miembro desde". El avatar y el nombre son editables.
class _Cabecera extends ConsumerWidget {
  const _Cabecera({required this.perfil});

  final PerfilUsuario perfil;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      children: [
        CircleAvatar(
          radius: 44,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(perfil.avatar, style: const TextStyle(fontSize: 44)),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                perfil.displayName,
                style: theme.textTheme.titleLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: 'Editar perfil',
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _editar(context, ref, perfil),
            ),
          ],
        ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            _Chip(
              icon: perfil.isAnonymous
                  ? Icons.person_outline
                  : Icons.verified_user,
              texto: perfil.isAnonymous ? 'Cuenta demo' : 'Cuenta permanente',
            ),
            if (perfil.inviteCode.isNotEmpty)
              _Chip(icon: Icons.qr_code, texto: perfil.inviteCode),
            if (perfil.creadoEn != null)
              _Chip(
                icon: Icons.calendar_today,
                texto: 'Miembro desde ${fechaCorta(perfil.creadoEn!)}',
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _editar(
    BuildContext context,
    WidgetRef ref,
    PerfilUsuario perfil,
  ) async {
    // Capturado antes del await para no usar `context` tras el gap asíncrono.
    final messenger = ScaffoldMessenger.of(context);
    final resultado = await showDialog<({String nombre, String avatar})>(
      context: context,
      builder: (_) => _DialogoEditar(perfil: perfil),
    );
    if (resultado == null) return;

    try {
      await ref.read(authRepositoryProvider).actualizarPerfil(
            displayName: resultado.nombre,
            avatar: resultado.avatar,
          );
      messenger.showSnackBar(
        const SnackBar(content: Text('Perfil actualizado')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo actualizar: $e')),
      );
    }
  }
}

/// Diálogo de edición de nombre y avatar. Devuelve el nombre y avatar elegidos.
class _DialogoEditar extends StatefulWidget {
  const _DialogoEditar({required this.perfil});

  final PerfilUsuario perfil;

  @override
  State<_DialogoEditar> createState() => _DialogoEditarState();
}

class _DialogoEditarState extends State<_DialogoEditar> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.perfil.displayName);
  late String _avatar = widget.perfil.avatar;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar perfil'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            maxLength: 24,
            decoration: const InputDecoration(labelText: 'Nombre visible'),
          ),
          const SizedBox(height: 8),
          const Text('Avatar'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final emoji in _avatares)
                GestureDetector(
                  onTap: () => setState(() => _avatar = emoji),
                  child: CircleAvatar(
                    backgroundColor: _avatar == emoji
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Colors.transparent,
                    child: Text(emoji, style: const TextStyle(fontSize: 20)),
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final nombre = _ctrl.text.trim();
            if (nombre.isEmpty) return;
            Navigator.of(context).pop((nombre: nombre, avatar: _avatar));
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

/// Tarjeta de saldo con acceso al historial de movimientos.
class _TarjetaSaldo extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saldo = ref.watch(saldoProvider).valueOrNull ?? 0;
    return Card(
      child: ListTile(
        leading: const Text('💰', style: TextStyle(fontSize: 28)),
        title: const Text('Saldo'),
        subtitle: Text(dinero(saldo), style: const TextStyle(fontSize: 18)),
        trailing: TextButton.icon(
          icon: const Icon(Icons.history),
          label: const Text('Historial'),
          onPressed: () => context.push('/historial'),
        ),
      ),
    );
  }
}

/// Tarjeta de nivel: nombre del nivel, XP y barra de progreso al siguiente.
class _TarjetaNivel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(estadisticasProvider).valueOrNull;
    final progreso = progresoDeXp(stats?.xp ?? 0);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Nivel ${progreso.nivel.indice + 1} · ${progreso.nivel.nombre}',
                  style: theme.textTheme.titleMedium,
                ),
                const Spacer(),
                Text('${progreso.xp} XP', style: theme.textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progreso.fraccion,
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              progreso.esMaximo
                  ? '¡Nivel máximo alcanzado!'
                  : 'Faltan ${progreso.xpRestante} XP para ${progreso.siguiente!.nombre}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Galería de logros: todos los del catálogo, los desbloqueados a color y los
/// pendientes en gris.
class _GaleriaLogros extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final desbloqueados =
        ref.watch(logrosProvider).valueOrNull?.toSet() ?? const <String>{};
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.6,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: [
        for (final logro in catalogoLogros)
          _TarjetaLogro(
            logro: logro,
            desbloqueado: desbloqueados.contains(logro.id),
          ),
      ],
    );
  }
}

class _TarjetaLogro extends StatelessWidget {
  const _TarjetaLogro({required this.logro, required this.desbloqueado});

  final Logro logro;
  final bool desbloqueado;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: desbloqueado ? 1 : 0.4,
      child: Card(
        color: desbloqueado ? theme.colorScheme.secondaryContainer : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Text(
                desbloqueado ? logro.emoji : '🔒',
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      logro.nombre,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      logro.descripcion,
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grilla de estadísticas de juego.
class _GrillaEstadisticas extends StatelessWidget {
  const _GrillaEstadisticas({required this.stats});

  final Estadisticas stats;

  @override
  Widget build(BuildContext context) {
    if (stats.manosJugadas == 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Todavía no jugaste ninguna mano multijugador. '
          '¡Únete a una sala para empezar a sumar estadísticas!',
        ),
      );
    }
    final items = <({String etiqueta, String valor})>[
      (etiqueta: 'Manos jugadas', valor: '${stats.manosJugadas}'),
      (
        etiqueta: '% victoria',
        valor: '${stats.porcentajeVictoria.toStringAsFixed(0)}%'
      ),
      (etiqueta: 'Ganadas', valor: '${stats.ganadas}'),
      (etiqueta: 'Perdidas', valor: '${stats.perdidas}'),
      (etiqueta: 'Empates', valor: '${stats.empates}'),
      (etiqueta: 'Blackjacks', valor: '${stats.blackjacks}'),
      (etiqueta: 'Mayor ganancia', valor: dinero(stats.mayorGanancia)),
      (etiqueta: 'Racha actual', valor: '${stats.rachaActual}'),
      (etiqueta: 'Mejor racha', valor: '${stats.mejorRacha}'),
      (etiqueta: 'Total apostado', valor: dinero(stats.totalApostado)),
      (etiqueta: 'Total ganado', valor: dinero(stats.totalGanado)),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.4,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: [
        for (final it in items)
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    it.etiqueta,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    it.valor,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Aviso para que las cuentas demo se conviertan en permanentes.
class _AvisoAnonimo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: ListTile(
        leading: const Icon(Icons.warning_amber),
        title: const Text('Cuenta demo'),
        subtitle: const Text(
          'Crea una cuenta para no perder tu saldo, amigos y estadísticas.',
        ),
        trailing: FilledButton(
          onPressed: () => context.push('/convertir'),
          child: const Text('Crear'),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.texto});

  final IconData icon;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(texto),
      visualDensity: VisualDensity.compact,
    );
  }
}
