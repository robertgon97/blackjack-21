import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../wallet/presentation/wallet_provider.dart';
import '../domain/contacto.dart';
import 'friends_provider.dart';

class TransferPage extends ConsumerStatefulWidget {
  const TransferPage({required this.contacto, super.key});

  final Contacto contacto;

  @override
  ConsumerState<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends ConsumerState<TransferPage> {
  final _formKey = GlobalKey<FormState>();
  final _montoController = TextEditingController();
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _montoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saldo = ref.watch(saldoProvider).valueOrNull ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Transferir créditos')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TarjetaDestinatario(contacto: widget.contacto),
              const SizedBox(height: 24),
              Text(
                'Tu saldo disponible: $saldo créditos',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _montoController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Monto a transferir',
                  hintText: '0',
                  suffixText: 'créditos',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n <= 0) {
                    return 'Ingresa un monto válido (entero positivo)';
                  }
                  if (n > saldo) return 'Saldo insuficiente';
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _enviando ? null : _confirmarTransferencia,
                icon: _enviando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: const Text('Transferir'),
              ),
              const SizedBox(height: 12),
              Text(
                'La transferencia es irreversible.\nMáx. 10 por hora.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmarTransferencia() async {
    if (!_formKey.currentState!.validate()) return;
    final monto = int.parse(_montoController.text);
    final nombre = widget.contacto.displayName;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar transferencia'),
        content: Text('¿Enviar $monto créditos a $nombre?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() {
      _enviando = true;
      _error = null;
    });

    try {
      await ref.read(friendsRepositoryProvider).transferirCreditos(
        toUid: widget.contacto.uid,
        monto: monto,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Transferencia exitosa: $monto créditos enviados a $nombre',
          ),
        ),
      );
      Navigator.of(context).pop();
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _error = switch (e.code) {
          'failed-precondition' => 'Saldo insuficiente.',
          'resource-exhausted' =>
              'Límite de 10 transferencias por hora alcanzado.',
          'invalid-argument' => e.message ?? 'Datos inválidos.',
          'not-found' => 'Usuario no encontrado.',
          _ => 'Error: ${e.message}',
        };
        _enviando = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error inesperado: $e';
        _enviando = false;
      });
    }
  }
}

class _TarjetaDestinatario extends StatelessWidget {
  const _TarjetaDestinatario({required this.contacto});

  final Contacto contacto;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Text(
          contacto.avatar,
          style: const TextStyle(fontSize: 36),
        ),
        title: Text(contacto.displayName),
        subtitle: const Text('Destinatario'),
      ),
    );
  }
}
