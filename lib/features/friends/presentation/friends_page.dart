import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/presentation/auth_provider.dart';
import '../domain/contacto.dart';
import '../domain/resultado_busqueda.dart';
import 'friends_provider.dart';

class FriendsPage extends ConsumerStatefulWidget {
  const FriendsPage({super.key});

  @override
  ConsumerState<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends ConsumerState<FriendsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final perfil = ref.watch(perfilStreamProvider).valueOrNull;
    final contactosAsync = ref.watch(contactosProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Amigos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Agregar amigo',
            onPressed: () => _abrirBusqueda(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Amigos'),
            Tab(icon: Icon(Icons.mail_outline), text: 'Solicitudes'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (perfil != null)
            _CodigoInvitacion(codigo: perfil.inviteCode),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _TabAmigos(
                  contactosAsync: contactosAsync,
                  myUid: perfil?.uid ?? '',
                ),
                _TabSolicitudes(
                  contactosAsync: contactosAsync,
                  myUid: perfil?.uid ?? '',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _abrirBusqueda(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => const _DialogoBuscarAmigo(),
    );
  }
}

// ── Encabezado: código de invitación ────────────────────────────────────────

class _CodigoInvitacion extends StatelessWidget {
  const _CodigoInvitacion({required this.codigo});

  final String codigo;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: () {
          Clipboard.setData(ClipboardData(text: codigo));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Código copiado al portapapeles')),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.qr_code, size: 18),
              const SizedBox(width: 8),
              Text(
                'Tu código: ',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                codigo,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
              ),
              const Spacer(),
              const Icon(Icons.copy, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tab Amigos ───────────────────────────────────────────────────────────────

class _TabAmigos extends ConsumerWidget {
  const _TabAmigos({
    required this.contactosAsync,
    required this.myUid,
  });

  final AsyncValue<List<Contacto>> contactosAsync;
  final String myUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return contactosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (todos) {
        final amigos = todos
            .where((c) => c.estado == EstadoAmistad.aceptada)
            .toList();
        if (amigos.isEmpty) {
          return const _EstadoVacio(
            icono: Icons.people_outline,
            mensaje: 'Aún no tienes amigos.\nBusca a alguien por su código.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: amigos.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (ctx, i) => _TarjetaAmigo(
            contacto: amigos[i],
            onTransferir: () => ctx.push('/friends/transfer', extra: amigos[i]),
          ),
        );
      },
    );
  }
}

class _TarjetaAmigo extends StatelessWidget {
  const _TarjetaAmigo({
    required this.contacto,
    required this.onTransferir,
  });

  final Contacto contacto;
  final VoidCallback onTransferir;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Text(
          contacto.avatar,
          style: const TextStyle(fontSize: 30),
        ),
        title: Text(contacto.displayName),
        trailing: FilledButton.tonal(
          onPressed: onTransferir,
          child: const Text('Transferir'),
        ),
      ),
    );
  }
}

// ── Tab Solicitudes ──────────────────────────────────────────────────────────

class _TabSolicitudes extends ConsumerWidget {
  const _TabSolicitudes({
    required this.contactosAsync,
    required this.myUid,
  });

  final AsyncValue<List<Contacto>> contactosAsync;
  final String myUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return contactosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (todos) {
        final pendientes =
            todos.where((c) => c.estado == EstadoAmistad.pendiente).toList();
        final recibidas = pendientes.where((c) => !c.yoEnvie(myUid)).toList();
        final enviadas = pendientes.where((c) => c.yoEnvie(myUid)).toList();

        if (pendientes.isEmpty) {
          return const _EstadoVacio(
            icono: Icons.inbox_outlined,
            mensaje: 'No hay solicitudes pendientes.',
          );
        }

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (recibidas.isNotEmpty) ...[
              _Seccion(titulo: 'Recibidas (${recibidas.length})'),
              for (final c in recibidas)
                _TarjetaSolicitudRecibida(
                  contacto: c,
                  onAceptar: () => _aceptar(ref, context, c),
                  onRechazar: () => _eliminar(ref, context, c),
                ),
              const SizedBox(height: 12),
            ],
            if (enviadas.isNotEmpty) ...[
              _Seccion(titulo: 'Enviadas (${enviadas.length})'),
              for (final c in enviadas)
                _TarjetaSolicitudEnviada(
                  contacto: c,
                  onCancelar: () => _eliminar(ref, context, c),
                ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _aceptar(
    WidgetRef ref,
    BuildContext context,
    Contacto contacto,
  ) async {
    try {
      await ref.read(friendsRepositoryProvider).aceptarSolicitud(
            myUid: myUid,
            friendUid: contacto.uid,
          );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _eliminar(
    WidgetRef ref,
    BuildContext context,
    Contacto contacto,
  ) async {
    try {
      await ref.read(friendsRepositoryProvider).eliminarContacto(
            myUid: myUid,
            friendUid: contacto.uid,
          );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo});

  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        titulo,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _TarjetaSolicitudRecibida extends StatelessWidget {
  const _TarjetaSolicitudRecibida({
    required this.contacto,
    required this.onAceptar,
    required this.onRechazar,
  });

  final Contacto contacto;
  final VoidCallback onAceptar;
  final VoidCallback onRechazar;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Text(
          contacto.avatar,
          style: const TextStyle(fontSize: 30),
        ),
        title: Text(contacto.displayName),
        subtitle: const Text('Quiere ser tu amigo'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              color: Colors.green,
              tooltip: 'Aceptar',
              onPressed: onAceptar,
            ),
            IconButton(
              icon: const Icon(Icons.cancel_outlined),
              color: Colors.red,
              tooltip: 'Rechazar',
              onPressed: onRechazar,
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaSolicitudEnviada extends StatelessWidget {
  const _TarjetaSolicitudEnviada({
    required this.contacto,
    required this.onCancelar,
  });

  final Contacto contacto;
  final VoidCallback onCancelar;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Text(
          contacto.avatar,
          style: const TextStyle(fontSize: 30),
        ),
        title: Text(contacto.displayName),
        subtitle: const Text('Solicitud enviada'),
        trailing: TextButton(
          onPressed: onCancelar,
          child: const Text('Cancelar'),
        ),
      ),
    );
  }
}

// ── Estado vacío ─────────────────────────────────────────────────────────────

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio({required this.icono, required this.mensaje});

  final IconData icono;
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// ── Diálogo: buscar amigo por código ────────────────────────────────────────

class _DialogoBuscarAmigo extends ConsumerStatefulWidget {
  const _DialogoBuscarAmigo();

  @override
  ConsumerState<_DialogoBuscarAmigo> createState() =>
      _DialogoBuscarAmigoState();
}

class _DialogoBuscarAmigoState extends ConsumerState<_DialogoBuscarAmigo> {
  final _controller = TextEditingController();
  bool _buscando = false;
  bool _enviando = false;
  ResultadoBusqueda? _resultado;
  String? _errorBusqueda;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar amigo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Código de invitación',
              hintText: 'Ej. BJ-AB12',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) {
              if (_resultado != null || _errorBusqueda != null) {
                setState(() {
                  _resultado = null;
                  _errorBusqueda = null;
                });
              }
            },
          ),
          const SizedBox(height: 12),
          if (_buscando)
            const Center(child: CircularProgressIndicator())
          else if (_resultado != null)
            _ResultadoCard(resultado: _resultado!)
          else if (_errorBusqueda != null)
            Text(
              _errorBusqueda!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        if (_resultado == null)
          FilledButton(
            onPressed: _buscando ? null : _buscar,
            child: const Text('Buscar'),
          )
        else
          FilledButton(
            onPressed: _enviando ? null : _enviarSolicitud,
            child: _enviando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Enviar solicitud'),
          ),
      ],
    );
  }

  Future<void> _buscar() async {
    final code = _controller.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _buscando = true;
      _errorBusqueda = null;
    });
    try {
      final repo = ref.read(friendsRepositoryProvider);
      final res = await repo.buscarPorCodigo(code);
      if (!mounted) return;
      if (res == null) {
        setState(() {
          _errorBusqueda = 'No se encontró ningún jugador con ese código.';
          _buscando = false;
        });
      } else {
        final myUid = ref.read(perfilStreamProvider).valueOrNull?.uid;
        if (res.uid == myUid) {
          setState(() {
            _errorBusqueda = 'Ese es tu propio código.';
            _buscando = false;
          });
        } else {
          setState(() {
            _resultado = res;
            _buscando = false;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorBusqueda = 'Error al buscar: $e';
        _buscando = false;
      });
    }
  }

  Future<void> _enviarSolicitud() async {
    final res = _resultado;
    if (res == null) return;
    final perfil = ref.read(perfilStreamProvider).valueOrNull;
    if (perfil == null) return;

    setState(() => _enviando = true);
    try {
      await ref.read(friendsRepositoryProvider).enviarSolicitud(
            myUid: perfil.uid,
            myDisplayName: perfil.displayName,
            myAvatar: perfil.avatar,
            amigo: res,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Solicitud enviada a ${res.displayName}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorBusqueda = 'Error al enviar solicitud: $e';
        _enviando = false;
      });
    }
  }
}

class _ResultadoCard extends StatelessWidget {
  const _ResultadoCard({required this.resultado});

  final ResultadoBusqueda resultado;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Text(
          resultado.avatar,
          style: const TextStyle(fontSize: 28),
        ),
        title: Text(resultado.displayName),
        subtitle: const Text('¿Enviar solicitud de amistad?'),
      ),
    );
  }
}
