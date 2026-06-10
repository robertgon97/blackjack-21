import 'package:flutter/material.dart';

import '../../domain/modelos.dart';

/// Tarjeta de sala para el lobby.
class FichaSala extends StatelessWidget {
  const FichaSala({
    super.key,
    required this.sala,
    required this.onUnirse,
  });

  final Sala sala;
  final VoidCallback onUnirse;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activos = sala.jugadoresActivos;
    final disponible =
        sala.status == EstadoSala.waiting || sala.status == EstadoSala.betting;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          children: [
            Expanded(
              child: Text(
                sala.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _EstadoChip(status: sala.status),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Icon(Icons.person, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                '${activos.length}/${sala.maxPlayers}',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const SizedBox(width: 16),
              Icon(Icons.attach_money, size: 14, color: cs.onSurfaceVariant),
              Text(
                '${sala.config.configJuego.apuestaMin}–${sala.config.configJuego.apuestaMax}',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const SizedBox(width: 8),
              Text(
                'Host: ${sala.hostName}',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
        ),
        trailing: FilledButton.tonal(
          onPressed: disponible && !sala.estaLlena ? onUnirse : null,
          child: const Text('Unirse'),
        ),
      ),
    );
  }
}

class _EstadoChip extends StatelessWidget {
  const _EstadoChip({required this.status});
  final EstadoSala status;

  @override
  Widget build(BuildContext context) {
    final (color, texto) = switch (status) {
      EstadoSala.waiting => (Colors.green, 'Esperando'),
      EstadoSala.betting => (Colors.orange, 'Apostando'),
      EstadoSala.playing => (Colors.blue, 'Jugando'),
      EstadoSala.finished => (Colors.grey, 'Finalizada'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        texto,
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
