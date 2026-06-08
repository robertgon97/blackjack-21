import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/i_auth_repository.dart';
import 'auth_provider.dart';

/// Pantalla de inicio de sesión: email/contraseña, Google y modo demo anónimo.
class PantallaLogin extends ConsumerStatefulWidget {
  const PantallaLogin({super.key});

  @override
  ConsumerState<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends ConsumerState<PantallaLogin> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _cargando = false;
  bool _modoRegistro = false;
  final _nombreCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitEmailPass() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final repo = ref.read(authRepositoryProvider);
      if (_modoRegistro) {
        await repo.registrar(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
          displayName: _nombreCtrl.text.trim(),
        );
      } else {
        await repo.entrarConEmail(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
        );
      }
    } catch (e) {
      setState(() => _error = _mensajeError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _entrarGoogle() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).entrarConGoogle();
    } catch (e) {
      setState(() => _error = _mensajeError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _entrarAnonimo() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).entrarAnonimo();
    } catch (e) {
      setState(() => _error = _mensajeError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String _mensajeError(Object e) {
    final msg = e.toString();
    if (msg.contains('wrong-password') || msg.contains('user-not-found')) {
      return 'Email o contraseña incorrectos.';
    }
    if (msg.contains('email-already-in-use')) {
      return 'Ese email ya está registrado.';
    }
    if (msg.contains('weak-password')) return 'Contraseña muy débil (mín. 6 caracteres).';
    if (msg.contains('cancelado')) return 'Login cancelado.';
    return 'Error al iniciar sesión. Intenta de nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
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
                    '🃏 Blackjack 21',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 32),
                  if (_modoRegistro) ...[
                    TextFormField(
                      controller: _nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de jugador',
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                    ),
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? 'Email inválido' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    validator: (v) =>
                        (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
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
                    onPressed: _cargando ? null : _submitEmailPass,
                    child: _cargando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_modoRegistro ? 'Registrarse' : 'Entrar'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _cargando ? null : _entrarGoogle,
                    icon: const Text('G', style: TextStyle(fontWeight: FontWeight.bold)),
                    label: const Text('Continuar con Google'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _cargando ? null : _entrarAnonimo,
                    child: const Text('Jugar sin registrarse (modo demo)'),
                  ),
                  const Divider(height: 32),
                  TextButton(
                    onPressed: () => setState(() {
                      _modoRegistro = !_modoRegistro;
                      _error = null;
                    }),
                    child: Text(
                      _modoRegistro
                          ? '¿Ya tienes cuenta? Inicia sesión'
                          : '¿No tienes cuenta? Regístrate',
                    ),
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
