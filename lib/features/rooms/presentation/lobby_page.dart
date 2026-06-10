import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formato.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../game/domain/modelos.dart' show ConfigJuego;
import '../domain/modelos.dart';
import 'sala_provider.dart';
import 'widgets/ficha_sala.dart';

/// Lobby: lista de salas públicas + botón para crear nueva sala.
class LobbyPage extends ConsumerWidget {
  const LobbyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salasAsync = ref.watch(salasPublicasProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Salas multijugador'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: () => ref.invalidate(salasPublicasProvider),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Unirse por código',
            onPressed: () => _mostrarDialogoCode(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarCrearSala(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Crear mesa'),
      ),
      body: salasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (salas) {
          if (salas.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.casino, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No hay mesas disponibles.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Crea una o únete por código.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: salas.length,
            itemBuilder: (_, i) => FichaSala(
              sala: salas[i],
              onUnirse: () => _unirse(context, ref, salas[i]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _unirse(BuildContext context, WidgetRef ref, Sala sala) async {
    if (!context.mounted) return;
    final perfil = ref.read(perfilStreamProvider).valueOrNull;
    if (perfil == null) return;
    try {
      await ref.read(salaRepositoryProvider).unirseASala(
            roomId: sala.id,
            uid: perfil.uid,
            displayName: perfil.displayName,
            avatar: perfil.avatar,
            balance: perfil.balance,
            comoEspectador: false,
          );
      if (context.mounted) await context.push('/room/${sala.id}');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  void _mostrarDialogoCode(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Unirse por código'),
        content: TextField(
          controller: ctrl,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: 'Ej. ABCD12',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.tag),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _unirPorCodigo(context, ref, ctrl.text.trim());
            },
            child: const Text('Unirse'),
          ),
        ],
      ),
    );
  }

  Future<void> _unirPorCodigo(
    BuildContext context,
    WidgetRef ref,
    String code,
  ) async {
    if (code.isEmpty) return;
    final repo = ref.read(salaRepositoryProvider);
    final sala = await repo.buscarPorCodigo(code);
    if (!context.mounted) return;
    if (sala == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código no encontrado.')),
      );
      return;
    }
    await _unirse(context, ref, sala);
  }

  void _mostrarCrearSala(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _FormCrearSala(
        onCrear: (sala) {
          Navigator.pop(context);
          context.push('/room/$sala');
        },
      ),
    );
  }
}

// ── Formulario de creación de sala ───────────────────────────────────────────

class _FormCrearSala extends ConsumerStatefulWidget {
  const _FormCrearSala({required this.onCrear});
  final void Function(String roomId) onCrear;

  @override
  ConsumerState<_FormCrearSala> createState() => _FormCrearSalaState();
}

class _FormCrearSalaState extends ConsumerState<_FormCrearSala> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController(text: 'Mesa de blackjack');

  int _maxJugadores = 4;
  bool _privada = false;
  int _apuestaMin = 10;
  int _apuestaMax = 500;
  bool _ocupado = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    if (!_formKey.currentState!.validate()) return;
    final perfil = ref.read(perfilStreamProvider).valueOrNull;
    if (perfil == null) return;
    setState(() => _ocupado = true);
    try {
      final config = ConfigSala(
        configJuego: ConfigJuego(
          apuestaMin: _apuestaMin,
          apuestaMax: _apuestaMax,
        ),
      );
      final roomId = await ref.read(salaRepositoryProvider).crearSala(
            hostUid: perfil.uid,
            hostName: perfil.displayName,
            hostAvatar: perfil.avatar,
            hostBalance: perfil.balance,
            nombre: _nombreCtrl.text.trim(),
            maxJugadores: _maxJugadores,
            privada: _privada,
            config: config,
          );
      if (mounted) widget.onCrear(roomId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Nueva mesa',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre de la mesa',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.table_restaurant),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Jugadores máx:'),
                const Spacer(),
                DropdownButton<int>(
                  value: _maxJugadores,
                  items: [1, 2, 3, 4, 5, 6]
                      .map(
                        (n) => DropdownMenuItem(
                          value: n,
                          child: Text('$n'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _maxJugadores = v!),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _CampoApuesta(
                    label: 'Apuesta mínima',
                    valor: _apuestaMin,
                    opciones: const [5, 10, 25, 50],
                    onCambio: (v) => setState(() => _apuestaMin = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CampoApuesta(
                    label: 'Apuesta máxima',
                    valor: _apuestaMax,
                    opciones: const [100, 250, 500, 1000],
                    onCambio: (v) => setState(() => _apuestaMax = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Mesa privada'),
              subtitle: const Text('Solo por enlace de invitación'),
              value: _privada,
              onChanged: (v) => setState(() => _privada = v),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _ocupado ? null : _crear,
              icon: _ocupado
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.casino),
              label: const Text('Crear mesa'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CampoApuesta extends StatelessWidget {
  const _CampoApuesta({
    required this.label,
    required this.valor,
    required this.opciones,
    required this.onCambio,
  });

  final String label;
  final int valor;
  final List<int> opciones;
  final void Function(int) onCambio;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        DropdownButton<int>(
          value: opciones.contains(valor) ? valor : opciones.first,
          isExpanded: true,
          items: opciones
              .map(
                (v) => DropdownMenuItem(
                  value: v,
                  child: Text(dinero(v)),
                ),
              )
              .toList(),
          onChanged: (v) => onCambio(v!),
        ),
      ],
    );
  }
}
