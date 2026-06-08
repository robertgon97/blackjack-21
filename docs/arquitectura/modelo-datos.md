# Arquitectura — Modelo de datos (Firestore)

Todas las colecciones viven en Cloud Firestore. Los campos marcados con 🔒 **solo pueden ser escritos
por Cloud Functions** (el cliente no tiene permiso); ver [`seguridad.md`](seguridad.md).

## `users/{uid}`

El documento de perfil de cada usuario. El `uid` es el de Firebase Auth.

| Campo | Tipo | Notas |
|-------|------|-------|
| `displayName` | string | Nombre visible |
| `email` | string | Correo (vacío si es anónimo) |
| `avatar` | string | Emoji elegido o URL de foto de Google |
| `balance` | int | 🔒 Saldo de créditos. Solo Functions lo escriben |
| `inviteCode` | string | Código único para invitar (ej. `ROB-X4K2`) |
| `isAnonymous` | bool | `true` si es cuenta demo sin registrar |
| `stats` | map | `{ jugadas, ganadas, perdidas, blackjacks, rachaMaxima, mayorBanca }` |
| `nivel` | string | Nivel actual (derivado de `mayorBanca`) |
| `lastAdReward` | timestamp | 🔒 Última vez que cobró un anuncio (throttle) |
| `createdAt` | timestamp | Fecha de creación |
| `lastSeen` | timestamp | Última actividad (presencia) |

### Sub-colección `users/{uid}/transactions/{txId}` 🔒

Historial de movimientos de créditos. **Solo Functions escriben aquí**; el cliente solo lee los suyos.

| Campo | Tipo | Notas |
|-------|------|-------|
| `type` | string | `win` · `loss` · `push` · `transfer_in` · `transfer_out` · `ad_reward` · `bonus_registro` · `bonus_invitacion` |
| `amount` | int | Monto del movimiento (positivo) |
| `balance_after` | int | Saldo resultante tras el movimiento |
| `description` | string | Texto legible (ej. "Ganaste la ronda - Blackjack") |
| `gameId` | string? | Opcional, si proviene de una partida |
| `fromUid` / `toUid` | string? | Solo en transferencias |
| `createdAt` | timestamp | Fecha |

## `friendships/{uid}/contacts/{friendUid}`

Relación de amistad. Se guarda en **ambos** lados (en `uid` y en `friendUid`) para poder listar amigos
de cada quien con una sola consulta.

| Campo | Tipo | Notas |
|-------|------|-------|
| `status` | string | `pending` · `accepted` |
| `initiatedBy` | string | uid de quien envió la solicitud |
| `since` | timestamp | Fecha de la solicitud / aceptación |

## `rooms/{roomId}`

Una mesa multijugador. Ver reglas en
[`../reglas-negocio/salas-y-multijugador.md`](../reglas-negocio/salas-y-multijugador.md).

| Campo | Tipo | Notas |
|-------|------|-------|
| `hostUid` | string | Dueño de la sala |
| `hostName` | string | Nombre del host (cache para listar) |
| `name` | string | Nombre de la mesa |
| `status` | string | `waiting` · `betting` · `playing` · `finished` |
| `maxPlayers` | int | 1–6 |
| `private` | bool | Si es privada, no aparece en el lobby público |
| `inviteCode` | string | Código del link `/join/CODE` |
| `config` | map | `ConfigJuego` + `{ turnosSimultaneos, timerSeg, commsHabilitado }` |
| `players` | map | `uid → { displayName, avatar, balance, ready, connected, seat, isSpectator, micActivo, camActiva }` |
| `createdAt` | timestamp | Fecha |

### Sub-colección `rooms/{roomId}/chat/{msgId}`

Chat de la sala (texto y emojis). Ligero; no depende del proveedor de voz/video.

| Campo | Tipo | Notas |
|-------|------|-------|
| `uid` | string | Autor |
| `displayName` | string | Nombre del autor |
| `texto` | string? | Mensaje de texto |
| `emoji` | string? | Reacción tipo emoji |
| `createdAt` | timestamp | Fecha |

## `games/{gameId}` 🔒

Estado de una ronda en curso. **Escrito solo por Functions** (reparto y resolución anti-trampa); los
clientes solo leen, y la UI muestra a cada jugador sus cartas + las visibles del crupier.

| Campo | Tipo | Notas |
|-------|------|-------|
| `roomId` | string | Sala a la que pertenece |
| `round` | int | Número de ronda |
| `phase` | string | `betting` · `dealing` · `player_turns` · `dealer` · `resolved` |
| `dealerCards` | array | Cartas del crupier `[{ palo, valor }]` |
| `dealerHidden` | bool | Si la primera carta sigue oculta |
| `shoe` | array | 🔒 Estado del mazo (no se expone al cliente) |
| `players` | map | `uid → { manos:[{cartas, apuesta, doblada, rendida, asPartido}], indiceMano, done, result }` |
| `updatedAt` | timestamp | Última actualización |

## Notas de diseño

- **Desnormalización controlada:** se cachean `displayName`/`avatar` en `rooms.players` para no leer N
  documentos de `users` al pintar la mesa.
- **Índices:** las consultas del lobby (`rooms` públicas por `status`/`createdAt`) y del leaderboard
  (`users` por `balance`) requieren índices compuestos → se declararán en `firestore.indexes.json`.
- **`shoe` server-side:** mantener el mazo en `games` (campo 🔒) evita que un cliente lea las próximas
  cartas. El reparto y la resolución se hacen en Functions.
