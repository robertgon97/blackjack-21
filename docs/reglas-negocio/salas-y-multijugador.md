# Reglas de negocio — Salas y multijugador

Una **sala** (room) es una mesa donde varios jugadores juegan Blackjack **contra el sistema** (el
crupier). Los jugadores **no compiten entre sí**: cada quien juega su mano contra el crupier, pero
comparten la mesa, el ritmo y la comunicación.

## Roles

| Rol | Descripción |
|-----|-------------|
| **Host** | Quien crea la sala. Controla la configuración y el inicio de cada ronda |
| **Jugador** | Participa apostando y jugando su mano |
| **Espectador** | Entra a mirar; no apuesta ni juega (`isSpectator: true`) |

## Crear y unirse

- El host crea la sala con un nombre, `maxPlayers` (1–6), visibilidad (`private`) y la configuración del
  juego (`ConfigJuego` + opciones de sala).
- Cada sala tiene un `inviteCode` que genera un **link de invitación** `/join/CODE` (deep link en móvil,
  URL en web).
- Salas **públicas** aparecen en el lobby; las **privadas** solo se unen por link.
- Un jugador puede unirse como jugador (toma un asiento libre, `seat`) o como espectador.

## Ciclo de una ronda

```
status: waiting   → la sala espera jugadores
status: betting   → fase de apuestas, countdown de 30 s
                    cada jugador apuesta y marca "ready"
                    cuando todos están listos o expira el countdown:
                    Function startRound() genera el shoe y reparte
status: playing   → turnos de los jugadores (ver abajo) + turno del crupier
                    Function resolveRound() paga/cobra y actualiza saldos
status: finished  → se muestran resultados; el host inicia otra ronda o se cierra la sala
```

## Turnos

- **Modo por defecto: simultáneos.** Todos los jugadores actúan a la vez sobre su propia mano. Es más
  ágil y, como cada quien juega contra el crupier, no necesita esperar a los demás.
- **Temporizador: 45 s** por defecto (`timerSeg`, configurable por el host). Si un jugador no actúa
  antes de que expire → se **planta automáticamente**.
- El host puede activar **turnos secuenciales** (por orden de asiento) si lo prefiere
  (`turnosSimultaneos: false`).
- Tras los jugadores, el crupier juega automáticamente según
  [`reglas-del-juego.md`](reglas-del-juego.md) (Function en servidor).

## Sincronización en tiempo real

- El estado de la sala (`rooms/{id}`) y de la partida (`games/{id}`) se observa con `snapshots()`:
  cuando un jugador actúa, los demás ven el cambio al instante.
- La UI de cada jugador muestra **sus** cartas y las **visibles** del crupier; el `shoe` no se expone
  (anti-trampa, ver [`../arquitectura/seguridad.md`](../arquitectura/seguridad.md)).

## Reparto y resolución (server-side)

- `startRound` (Function): genera y baraja el shoe, reparte 2 cartas a cada jugador y 2 al crupier (1
  oculta). Solo el host puede dispararla y solo en fase `betting`.
- `resolveRound` (Function): tras el turno del crupier, calcula el resultado de cada mano, actualiza el
  `balance` de cada jugador y escribe sus transacciones. Es **idempotente** (no paga dos veces).

## Comunicación en la sala

Mientras juegan, los miembros pueden comunicarse (ver [`../features/comms.md`](../features/comms.md)
cuando exista):
- **Chat de texto + emojis** (siempre disponible, vía Firestore).
- **Voz** (LiveKit), con botón de silencio.
- **Cámara opcional** (apagada por defecto) para ver reacciones.

`commsHabilitado` en la config de la sala permite al host activar/desactivar la voz y la cámara.

## Reglas y casos borde

- Apuestas dentro de `[apuestaMin, apuestaMax]` y nunca mayores al saldo del jugador.
- Si un jugador se **desconecta** (`connected: false`) durante su turno, se planta automáticamente al
  expirar el temporizador; su asiento puede liberarse al terminar la ronda.
- Si el **host** abandona, se transfiere el rol de host a otro jugador o la sala se cierra (decisión a
  implementar en la feature `rooms`).
- Una sala vacía (sin jugadores ni espectadores) se marca `finished` y se limpia.
