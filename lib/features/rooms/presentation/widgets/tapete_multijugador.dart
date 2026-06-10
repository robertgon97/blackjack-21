import 'package:flutter/material.dart';

import '../../../game/domain/cartas.dart';
import '../../../game/domain/modelos.dart';
import '../../../game/presentation/widgets/carta_widget.dart';
import '../../../game/presentation/widgets/zona_crupier_widget.dart';
import '../../domain/modelos.dart';

/// Tapete de la partida multijugador: crupier arriba, jugadores abajo.
class TapeteMultijugador extends StatelessWidget {
  const TapeteMultijugador({
    super.key,
    required this.sala,
    required this.partida,
    required this.miUid,
    required this.onAccion,
    required this.timerSeg,
  });

  final Sala sala;
  final EstadoPartida partida;
  final String miUid;
  final void Function(String accion) onAccion;
  final int timerSeg;

  @override
  Widget build(BuildContext context) {
    final misDatos = partida.players[miUid];
    final miBalance = sala.players[miUid]?.balance ?? 0;
    final otrosJugadores =
        partida.players.entries.where((e) => e.key != miUid).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Crupier ─────────────────────────────────────────────────────────
        ZonaCrupierWidget(
          cartas: partida.dealerCards,
          oculto: partida.dealerHidden,
        ),
        const SizedBox(height: 12),

        // ── Otros jugadores ──────────────────────────────────────────────────
        if (otrosJugadores.isNotEmpty) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: otrosJugadores.map((entry) {
                final uid = entry.key;
                final datos = entry.value;
                final jugador = sala.players[uid];
                return _ZonaOtroJugador(
                  nombre: jugador?.displayName ?? uid,
                  avatar: jugador?.avatar ?? '🃏',
                  datos: datos,
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── Mi zona ──────────────────────────────────────────────────────────
        if (misDatos != null)
          _MiZona(
            datos: misDatos,
            config: sala.config.configJuego,
            balance: miBalance,
            timerSeg: timerSeg,
            onAccion: onAccion,
          )
        else
          const Center(
            child: Text(
              'Esperando reparto...',
              style: TextStyle(color: Colors.white70),
            ),
          ),
      ],
    );
  }
}

// ── Zona de otro jugador ─────────────────────────────────────────────────────

class _ZonaOtroJugador extends StatelessWidget {
  const _ZonaOtroJugador({
    required this.nombre,
    required this.avatar,
    required this.datos,
  });

  final String nombre;
  final String avatar;
  final DatosJugadorPartida datos;

  @override
  Widget build(BuildContext context) {
    // Mostrar la mano que el otro jugador tiene activa (tras dividir, no la 1).
    final manoActiva = datos.manos.isEmpty
        ? null
        : datos.manos[datos.indiceMano.clamp(0, datos.manos.length - 1)];
    final puntos = manoActiva != null ? calcularPuntos(manoActiva.cartas) : 0;

    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: datos.done ? Colors.grey : Colors.white30,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(avatar, style: const TextStyle(fontSize: 20)),
          Text(
            nombre,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
          if (manoActiva != null) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children:
                  manoActiva.cartas.map((c) => _MiniCarta(carta: c)).toList(),
            ),
            Text(
              '$puntos',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          if (datos.done)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _colorResultado(datos.result),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _textoResultado(datos.result),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _colorResultado(String? r) => switch (r) {
        'win' || 'blackjack' => Colors.green,
        'lose' => Colors.red.shade700,
        'push' => Colors.orange,
        'surrender' => Colors.grey,
        _ => Colors.blueGrey,
      };

  String _textoResultado(String? r) => switch (r) {
        'win' => 'GANA',
        'blackjack' => 'BLACKJACK',
        'lose' => 'PIERDE',
        'push' => 'EMPATE',
        'surrender' => 'RENDIDO',
        _ => 'LISTO',
      };
}

class _MiniCarta extends StatelessWidget {
  const _MiniCarta({required this.carta});
  final Carta carta;

  @override
  Widget build(BuildContext context) {
    final roja = carta.palo == Palo.corazones || carta.palo == Palo.diamantes;
    return Container(
      margin: const EdgeInsets.only(right: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${carta.valor}${carta.palo.simbolo}',
        style: TextStyle(
          color: roja ? Colors.red : Colors.black,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ── Mi zona (con botones de acción) ─────────────────────────────────────────

class _MiZona extends StatelessWidget {
  const _MiZona({
    required this.datos,
    required this.config,
    required this.balance,
    required this.timerSeg,
    required this.onAccion,
  });

  final DatosJugadorPartida datos;
  final ConfigJuego config;
  final int balance;
  final int timerSeg;
  final void Function(String accion) onAccion;

  @override
  Widget build(BuildContext context) {
    final manoActiva = datos.indiceMano < datos.manos.length
        ? datos.manos[datos.indiceMano]
        : null;
    final puntos = manoActiva != null ? calcularPuntos(manoActiva.cartas) : 0;

    // Saldo disponible = balance pre-ronda menos las apuestas ya comprometidas
    // en las manos en juego (el servidor descuenta igual al resolver). Sin esto,
    // los botones DOBLAR/DIVIDIR sobrestimarían el saldo. La autoridad real
    // es la Cloud Function; esto es solo UX.
    final comprometido = datos.manos.fold<int>(0, (acc, m) => acc + m.apuesta);
    final saldoDisponible = balance - comprometido;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white30),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!datos.done && timerSeg > 0) _Temporizador(segundos: timerSeg),
          const SizedBox(height: 8),

          // Mis manos
          ...datos.manos.asMap().entries.map((e) {
            final activa = e.key == datos.indiceMano && !datos.done;
            return _ManoRow(
              mano: e.value,
              activa: activa,
              numero: datos.manos.length > 1 ? e.key + 1 : null,
            );
          }),

          const SizedBox(height: 8),
          if (manoActiva != null)
            Text(
              'Puntos: $puntos',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

          const SizedBox(height: 12),

          // Botones de acción
          if (!datos.done && manoActiva != null) ...[
            _BotonesAccion(
              mano: manoActiva,
              cantidadManos: datos.manos.length,
              balance: saldoDisponible,
              config: config,
              onAccion: onAccion,
            ),
          ] else if (datos.done) ...[
            _ResultadoChip(result: datos.result),
          ],
        ],
      ),
    );
  }
}

/// Muestra los segundos restantes. El contador real (1 Hz) lo lleva
/// `RoomPage`; aquí solo se renderiza el valor que llega por parámetro,
/// evitando la deriva de un temporizador independiente.
class _Temporizador extends StatelessWidget {
  const _Temporizador({required this.segundos});
  final int segundos;

  @override
  Widget build(BuildContext context) {
    final restantes = segundos < 0 ? 0 : segundos;
    final color = restantes <= 10 ? Colors.red : Colors.white70;
    return Text(
      'Tiempo: ${restantes}s',
      style: TextStyle(color: color, fontSize: 13),
    );
  }
}

class _ManoRow extends StatelessWidget {
  const _ManoRow({
    required this.mano,
    required this.activa,
    this.numero,
  });

  final ManoPartida mano;
  final bool activa;
  final int? numero;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (numero != null)
            Text(
              'Mano $numero ',
              style: TextStyle(
                color: activa ? Colors.amberAccent : Colors.white54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ...mano.cartas.map(
            (c) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: CartaWidget(carta: c, ancho: 44),
            ),
          ),
          if (mano.doblada)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(
                Icons.keyboard_double_arrow_up,
                color: Colors.amberAccent,
                size: 18,
              ),
            ),
          if (mano.rendida)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.flag, color: Colors.grey, size: 18),
            ),
        ],
      ),
    );
  }
}

class _BotonesAccion extends StatelessWidget {
  const _BotonesAccion({
    required this.mano,
    required this.cantidadManos,
    required this.balance,
    required this.config,
    required this.onAccion,
  });

  final ManoPartida mano;
  final int cantidadManos;
  final int balance;
  final ConfigJuego config;
  final void Function(String) onAccion;

  // Doblar y dividir exigen cubrir una apuesta adicional igual a la actual.
  bool get _saldoCubreApuesta => balance >= mano.apuesta;
  bool get _puedeDoblar =>
      mano.cartas.length == 2 && !mano.doblada && _saldoCubreApuesta;
  bool get _puedeDividir =>
      mano.cartas.length == 2 &&
      cantidadManos < 4 &&
      mano.cartas[0].valor == mano.cartas[1].valor &&
      _saldoCubreApuesta;
  bool get _puedeRendirse =>
      config.permitirRendirse && mano.cartas.length == 2 && cantidadManos == 1;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        FilledButton(
          onPressed: () => onAccion('pedir'),
          child: const Text('PEDIR'),
        ),
        FilledButton.tonal(
          onPressed: () => onAccion('plantarse'),
          child: const Text('PLANTARSE'),
        ),
        if (_puedeDoblar)
          ElevatedButton(
            onPressed: () => onAccion('doblar'),
            child: const Text('DOBLAR'),
          ),
        if (_puedeDividir)
          ElevatedButton(
            onPressed: () => onAccion('dividir'),
            child: const Text('DIVIDIR'),
          ),
        if (_puedeRendirse)
          OutlinedButton(
            onPressed: () => onAccion('rendirse'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('RENDIRSE'),
          ),
      ],
    );
  }
}

class _ResultadoChip extends StatelessWidget {
  const _ResultadoChip({this.result});
  final String? result;

  @override
  Widget build(BuildContext context) {
    final (color, texto) = switch (result) {
      'win' => (Colors.green, 'GANASTE'),
      'blackjack' => (Colors.amber, '¡BLACKJACK!'),
      'lose' => (Colors.red, 'PERDISTE'),
      'push' => (Colors.orange, 'EMPATE'),
      'surrender' => (Colors.grey, 'RENDIDO'),
      _ => (Colors.blueGrey, 'LISTO'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: color,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
