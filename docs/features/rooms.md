# Feature: Salas multijugador (Fase 5)

## Resumen

Salas de Blackjack donde varios jugadores comparten mesa contra el crupier automático. Cada jugador juega su mano de forma independiente (simultánea por defecto). El reparto y la resolución ocurren server-side (Cloud Functions) para garantizar la integridad del shoe.

## Casos de uso

| ID | Actor | Descripción |
|----|-------|-------------|
| CU-1 | Jugador | Crear una sala (pública o privada) con nombre, máximo de jugadores y reglas. |
| CU-2 | Jugador | Ver el lobby de salas públicas y unirse a una. |
| CU-3 | Jugador | Unirse por código de invitación (deep link `/join/CODE`). |
| CU-4 | Host | Iniciar la fase de apuestas cuando hay jugadores suficientes. |
| CU-5 | Jugador | Establecer apuesta y marcar "Listo". |
| CU-6 | Host | Iniciar la ronda (requiere todos listos). |
| CU-7 | Jugador | Pedir, plantarse, doblar, dividir o rendirse durante su turno (45 s de límite). |
| CU-8 | Sistema | El crupier juega automáticamente tras los jugadores; se resuelven manos y actualizan saldos. |
| CU-9 | Host | Iniciar una nueva ronda o cerrar la sala al finalizar. |

## Componentes creados

### Domain
- `lib/features/rooms/domain/modelos.dart` — `EstadoSala`, `ConfigSala`, `JugadorEnSala`, `Sala`, `EstadoPartida`, `DatosJugadorPartida`, `ManoPartida`.
- `lib/features/rooms/domain/i_sala_repository.dart` — Interfaz del repositorio.

### Data
- `lib/features/rooms/data/firestore_sala_repository.dart` — Implementación Firestore + Cloud Functions.

### Presentation
- `lib/features/rooms/presentation/sala_provider.dart` — Providers de Riverpod + `SalaActions`.
- `lib/features/rooms/presentation/lobby_page.dart` — Lobby (lista pública + formulario de creación).
- `lib/features/rooms/presentation/room_page.dart` — Página de sala (fases: waiting, betting, playing, finished).
- `lib/features/rooms/presentation/widgets/ficha_sala.dart` — Tarjeta de sala para el lobby.
- `lib/features/rooms/presentation/widgets/panel_apuestas_sala.dart` — Panel de apuesta multijugador.
- `lib/features/rooms/presentation/widgets/tapete_multijugador.dart` — Tapete de juego con todos los jugadores.

### Cloud Functions
- `functions/src/startRound.ts` — Genera shoe, reparte cartas, actualiza sala a 'playing'.
- `functions/src/playerAction.ts` — Procesa acción del jugador; auto-resuelve cuando todos terminan.

### Router
- `/lobby` — Lobby de salas públicas.
- `/room/:id` — Sala individual.
- `/join/:code` — Deep link de invitación (redirige al room).

## Modelo de datos

Ver `docs/arquitectura/modelo-datos.md`:
- `rooms/{roomId}` — Estado de la sala (players, config, status, currentGameId).
- `games/{gameId}` — Estado de la partida (dealerCards, players.{uid}.manos). Cliente solo lee; Functions escriben.
- `games/{gameId}/serverData/current` — Shoe (oculto al cliente vía reglas `allow read: if false`).

## Flujo de una ronda

```
waiting → [host] Iniciar apuestas → betting
betting → [todos] Establecer apuesta + Listo → [host] Iniciar ronda → playing
playing → [startRound Function] Reparte cartas → player_turns
player_turns → [playerAction Function] x N → resolved (crupier juega + pago)
resolved → sala pasa a finished → [host] Nueva ronda → betting
```

## Seguridad

- Reglas de Firestore refinadas: solo el host actualiza estado de sala; cada jugador solo actualiza su propia entrada en `players`.
- `games/serverData/current` bloqueado (`allow read: if false`): el shoe nunca llega al cliente.
- `startRound` valida que el caller es el host y todos están listos.
- `playerAction` es idempotente: si el jugador ya está `done`, retorna sin hacer nada.
- Balances actualizados dentro de la misma transacción que la resolución de manos.

## Pendiente (Fase 6)

- Chat de texto + emojis (subcol `rooms/{id}/chat`).
- Voz y cámara vía LiveKit (`comms/` feature).
