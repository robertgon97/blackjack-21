import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/transaccion.dart';
import 'wallet_provider.dart';

/// Pantalla de historial de movimientos de créditos.
class HistorialPage extends ConsumerWidget {
  const HistorialPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saldo = ref.watch(saldoProvider);
    final txs = ref.watch(transaccionesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Historial de créditos')),
      body: Column(
        children: [
          _TarjetaSaldo(saldo: saldo),
          Expanded(
            child: txs.when(
              data: (lista) => lista.isEmpty
                  ? const Center(child: Text('Sin movimientos aún.'))
                  : ListView.builder(
                      itemCount: lista.length,
                      itemBuilder: (_, i) => _FilaTransaccion(tx: lista[i]),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaSaldo extends StatelessWidget {
  const _TarjetaSaldo({required this.saldo});
  final AsyncValue<int> saldo;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.all(16),
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        child: Row(
          children: [
            const Text('💰', style: TextStyle(fontSize: 32)),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saldo actual',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                saldo.when(
                  data: (v) => Text(
                    '\$$v créditos',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimaryContainer,
                        ),
                  ),
                  loading: () => const CircularProgressIndicator(),
                  error: (_, __) => const Text('—'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaTransaccion extends StatelessWidget {
  const _FilaTransaccion({required this.tx});
  final Transaccion tx;

  @override
  Widget build(BuildContext context) {
    final color = tx.esIngreso ? Colors.green : Colors.red;
    final signo = tx.esIngreso ? '+' : '-';
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withAlpha(40),
        child: Text(_icono(tx.tipo), style: const TextStyle(fontSize: 18)),
      ),
      title: Text(tx.descripcion),
      subtitle: Text(_formatFecha(tx.fecha)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$signo\$${tx.monto}',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          Text(
            '\$${tx.balanceAfter}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String _icono(TipoTransaccion tipo) => switch (tipo) {
        TipoTransaccion.win => '🏆',
        TipoTransaccion.loss => '💸',
        TipoTransaccion.push => '🤝',
        TipoTransaccion.transferIn => '📥',
        TipoTransaccion.transferOut => '📤',
        TipoTransaccion.adReward => '📺',
        TipoTransaccion.bonusRegistro => '🎁',
        TipoTransaccion.bonusInvitacion => '👥',
        TipoTransaccion.bonusConversion => '⭐',
      };

  String _formatFecha(DateTime d) {
    return '${d.day}/${d.month}/${d.year}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
