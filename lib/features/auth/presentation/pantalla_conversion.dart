import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_provider.dart';

/// Formulario de conversión de cuenta demo (anónima) a permanente.
/// Conserva el `uid` (saldo, amigos, historial) y acredita +500 créditos.
class PantallaConversion extends ConsumerStatefulWidget {
  const PantallaConversion({super.key});

  @override
  ConsumerState<PantallaConversion> createState() => _PantallaConversionState();
}

class _PantallaConversionState extends ConsumerState<PantallaConversion> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  bool _cargando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // El nombre del demo viene precargado y es editable.
    final perfil = ref.read(perfilStreamProvider).valueOrNull;
    if (perfil != null) _nombreCtrl.text = perfil.displayName;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _convertirEmail() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).vincularConEmail(
            email: _emailCtrl.text.trim(),
            password: _passCtrl.text,
            displayName: _nombreCtrl.text.trim(),
          );
      _alExito();
    } catch (e) {
      setState(() => _error = _limpiar(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _convertirGoogle() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).vincularConGoogle();
      _alExito();
    } catch (e) {
      setState(() => _error = _limpiar(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _alExito() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '¡Cuenta creada! Tu bono de bienvenida se acreditará en breve.',
        ),
      ),
    );
    context.go('/');
  }

  String _limpiar(Object e) => e.toString().replaceFirst('Exception: ', '');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final perfil = ref.watch(perfilStreamProvider).valueOrNull;

    // Si la cuenta ya es permanente, no hay nada que convertir.
    if (perfil != null && !perfil.isAnonymous) {
      return Scaffold(
        appBar: AppBar(title: const Text('Crear cuenta')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Tu cuenta ya está registrada. No necesitas convertirla.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Volver al juego'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Crear tu cuenta')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Conserva tu progreso',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Crea una cuenta para no perder tu saldo, amigos e historial. '
                    'Te regalamos +500 créditos por registrarte.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de jugador',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Ingresa tu nombre'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                    ),
                    validator: (v) => (v == null ||
                            !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(v.trim()))
                        ? 'Email inválido'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    validator: (v) => (v == null || v.length < 6)
                        ? 'Mínimo 6 caracteres'
                        : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(color: cs.error),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _cargando ? null : _convertirEmail,
                    child: _cargando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Crear cuenta'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _cargando ? null : _convertirGoogle,
                    icon: const Text(
                      'G',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    label: const Text('Crear cuenta con Google'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _cargando ? null : () => context.go('/'),
                    child: const Text('Ahora no, seguir en modo demo'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
