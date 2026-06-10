# Errores y correcciones

Registro de errores cometidos por el asistente durante el desarrollo, con su corrección.
Sirve para no repetirlos y como historial de decisiones.

> **Protocolo:** cuando se detecta un error (en código, suposición o flujo), se documenta aquí
> antes de corregirlo. Formato: fecha, descripción del error, causa, corrección aplicada.

---

<!-- Ejemplo de entrada (descomentar y adaptar cuando ocurra un error real):

## 2026-XX-XX — Nombre breve del error

**Qué falló:** descripción concreta del problema (función, archivo, comportamiento incorrecto).

**Causa:** por qué ocurrió (suposición incorrecta, falta de contexto, bug en lógica).

**Corrección:** qué se cambió y en qué archivo.

**Aprendizaje:** qué hay que recordar para no repetirlo.

-->

---

## 2026-06-08 — Botones de acción vivos durante la resolución del blackjack natural

**Qué falló:** en `game/presentation/controlador_juego.dart`, al repartir un blackjack natural
(jugador o crupier con 21 de dos cartas), `repartir()` dejaba `animando = false` y luego
`_iniciarTurnoJugador()` revelaba al crupier y esperaba 600 ms antes de finalizar la ronda. Durante
esa pausa la fase seguía siendo `jugando` y `animando` era `false`, así que `BotonesAccion` quedaba
habilitado: el usuario podía pulsar PEDIR/PLANTARSE y disparar una segunda resolución de la ronda.

**Causa:** al traducir el flujo de `legacy-web/js/juego.js`, no se replicó que en el original la
`zona-juego` permanecía oculta hasta `jugarManoActiva()`. Aquí la visibilidad de los botones depende
solo de `fase == jugando && !animando`, y la rama de blackjack no marcaba `animando`.

**Corrección:** `_iniciarTurnoJugador()` ahora pone `animando = true` antes de revelar y pausar en la
rama de blackjack. Además se reforzaron los guards de fase: `repartir()` solo procede en fase
`apuestas`; `nuevaRonda()` y `pedirPrestamo()`, solo en `resultado`.

**Aprendizaje:** cuando la visibilidad/disponibilidad de un control se deriva del estado, toda ruta
que cierra una ronda sin pasar por el turno del jugador debe marcar `animando` (o una sub-fase de
"resolviendo") para bloquear la entrada durante las pausas. Lo detectó la revisión de código antes
de mezclar.

---

## 2026-06-10 — Hallazgos del review de Fase 5 (salas multijugador, PR #12)

**Qué falló:** la revisión de código del PR de salas multijugador detectó varios defectos antes de
mezclar:

1. `functions/src/playerAction.ts` — `manoIdx` recibido del cliente se usaba como índice sin validar
   rango ni que coincidiera con la mano activa → crash garantizado con índice fuera de rango y
   posibilidad de actuar sobre una mano ajena al turno.
2. `functions/src/playerAction.ts` (dividir) — al dividir, la mano nueva quedaba con una sola carta;
   en blackjack estándar cada mano dividida recibe una carta adicional inmediata.
3. `functions/src/startRound.ts` — la apuesta no se validaba contra el balance real del jugador; se
   podía apostar más de lo disponible.
4. `lib/features/rooms/data/firestore_sala_repository.dart` — `unirseASala` hacía read-then-write sin
   transacción → race condition por el último asiento libre.
5. `lib/features/rooms/presentation/widgets/tapete_multijugador.dart` — el `_Temporizador` usaba un
   `AnimationController` propio sobre `widget.segundos` (que ya venía decreciendo desde `RoomPage`),
   produciendo deriva creciente del número mostrado.
6. Mismo archivo — `balance: 0` hardcodeado: el cliente nunca bloqueaba DOBLAR/DIVIDIR por saldo.
7. CI en rojo independiente del review: el código del PR nunca pasó `dart format` y faltaba el
   import de `ConfigJuego` en `lobby_page.dart` (error de compilación que el CI no llegó a reportar
   porque moría antes, en el paso de formato).

**Causa:** confianza en datos del cliente sin validación server-side (1, 3); traducción incompleta de
la regla de división (2); falta de atomicidad en una operación leer-modificar-escribir (4); dos
fuentes de verdad para el mismo contador (5); placeholder dejado sin cablear (6); el PR se subió sin
correr `dart format`/`flutter analyze` localmente (7).

**Corrección:** validación de `manoIdx` (rango + igualdad con `indiceMano`); reparto de carta a ambas
manos al dividir, con auto-plante de ases divididos; lectura de los docs de usuario dentro de la
transacción de `startRound` para validar apuesta ≤ balance; `unirseASala` envuelto en
`runTransaction` (idempotente); `_Temporizador` convertido en `StatelessWidget` que solo renderiza el
valor recibido; balance real cableado desde `sala.players[miUid].balance` con bloqueo de
DOBLAR/DIVIDIR si no cubre la apuesta. Menores: typo «Mesa de poker» → «Mesa de blackjack», centinela
`epoch 0` en `Sala.fromDoc` para `createdAt` no resuelto, regla `soloActualizaSuJugador` bloquea la
fase `playing`, comentario de espejo en `playerAction.ts`. Más el import de `ConfigJuego` y el
formato del repo completo.

**Aprendizaje:** las Cloud Functions son la frontera anti-trampa: todo dato del cliente (índices,
apuestas) debe validarse contra el estado autoritativo antes de escribir. Las operaciones
leer-modificar-escribir sobre documentos compartidos van siempre en transacción. Y un solo contador
debe tener una sola fuente de verdad. Correr `dart format` + `flutter analyze --fatal-infos` +
`flutter test` localmente antes de abrir el PR habría evitado el CI rojo.

---

## 2026-06-10 — Segunda ronda de review de Fase 5 (PR #12)

**Qué falló:** una segunda revisión sobre los commits de corrección detectó hallazgos que la primera
no cubrió:

1. **Crítico — doblar/dividir «a crédito»** (`functions/src/playerAction.ts`): la validación de saldo
   solo existía en `startRound` (apuesta inicial). Durante la ronda, `users/{uid}.balance` todavía
   refleja el saldo previo (las apuestas se deducen al resolver), así que un jugador podía enviar
   `doblar`/`dividir` comprometiendo más de lo que tenía. El cliente (`_BotonesAccion`) usaba el mismo
   balance pre-ronda sin descontar las apuestas ya en juego, sobrestimando el saldo.
2. **`cambiarEstadoSala`** (`firestore_sala_repository.dart`): `get()` + `update()` sin transacción al
   limpiar `ready`/`apuesta` de todos los jugadores.
3. **`/join/:code`** (`app_router.dart`): el `redirect` ejecutaba `buscarPorCodigo` (query Firestore)
   sin verificar sesión; sin auth las reglas lanzarían una excepción no capturada.
4. Menores: `_ZonaOtroJugador` mostraba `manos.first` en vez de la mano activa (`indiceMano`);
   `room_page.dart` mutaba `_ultimaFase` dentro de `build()`; faltaban tests de dominio para `rooms`.

**Corrección:** en `playerAction` se calcula `saldoDisponible = balance − Σ apuestas comprometidas`
y se valida antes de `doblar`/`dividir`; el cliente replica ese cálculo en `_MiZona`
(`saldoDisponible`) y lo pasa a los botones. `cambiarEstadoSala` envuelto en `runTransaction`. El
`redirect` de `/join` verifica sesión antes del `await` y captura errores cayendo a `/lobby`.
`_ZonaOtroJugador` indexa por `indiceMano` (con `clamp`). El arranque del temporizador se mueve a
`ref.listen(salaProvider, …)` y se elimina `_ultimaFase`. Se añade `test/rooms_modelos_test.dart`
(10 tests de `jugadoresActivos`, `todosListos`, `asientosLibres`/`estaLlena` y `fromDoc`).

**Aprendizaje:** validar el saldo en la apuesta inicial no basta: cada acción que compromete fichas
adicionales (doblar, dividir) debe revalidar contra el saldo disponible descontando lo ya
comprometido en la ronda. Los efectos secundarios en Flutter (arrancar timers, etc.) van en
`ref.listen`/`didUpdateWidget`, nunca como asignación dentro de `build()`.

---

## 2026-06-10 — Tercera ronda de review de Fase 5 (PR #12)

**Qué falló:**

1. **`debePedirCrupier` fallaba con 17 suave de varios ases** (`functions/src/playerAction.ts`): la
   reimplementación detectaba el 17 suave buscando `suma === 6` (cartas no-as). Con manos multi-as
   válidas (A+A+5 = 17, A+A+A+4 = 17) daba `false`, así que con H17 el crupier se plantaba cuando
   debía pedir.
2. **`startRound` no validaba `apuesta >= apuestaMin`** (ni el máximo): solo comprobaba el saldo. Un
   cliente podía `establecerApuesta(1)` + `marcarListo` y arrancar la ronda por debajo del mínimo.
3. **`rooms/{id}/players/{uid}.balance` quedaba obsoleto tras cada ronda**: `playerAction` actualizaba
   `users/{uid}.balance` al resolver, pero no el espejo en `rooms`. En la ronda 2 el panel y la
   validación client-side de `saldoDisponible` usaban el saldo de cuando el jugador se unió.
4. **El botón «Salir» fallaba en silencio durante `playing`**: `_salir()` hacía `catch (_) {}` y
   `context.pop()` igual; las reglas impiden que un miembro borre su entrada en `playing`, así que el
   jugador salía de la pantalla pero seguía en `players`, ocupando asiento.

**Corrección:** se añade `infoMano` en TS (espejo de `cartas.dart`) y `debePedirCrupier` usa
`total === 17 && suave && h17`. `startRound` valida `apuestaMin`/`apuestaMax` además del saldo. La
resolución de `playerAction` refleja el nuevo balance en `rooms/{id}/players/{uid}.balance` dentro de
la misma transacción. `_salir()` solo hace `pop()` si la salida tuvo éxito; si falla, muestra un
aviso y mantiene al jugador en la sala.

**Aprendizaje:** las funciones de dominio reimplementadas en TS deben copiar el *algoritmo* del Dart
(p. ej. `infoMano` calcula "suave" reduciendo ases), no aproximarlo con heurísticas frágiles. Y si un
dato se duplica entre colecciones (balance en `users` y en `rooms/players`), toda escritura
autoritativa debe actualizar ambas copias en la misma transacción.

**Pendiente para Fase 6 (mejoras menores del review, no bugs):** fichas de apuesta de
`PanelApuestasSala` que respeten `apuestaMin`; `salaActionsProvider` con `autoDispose`.

---

## 2026-06-10 — Hallazgos finales del review de Fase 5 (post-merge del PR #12)

**Qué falló:** el review automático dejó 6 comentarios inline sobre el último commit justo cuando se
mergeó el PR #12, así que no se atendieron en su momento:

1. **Seguridad — `firestore.rules`:** `soloActualizaSuJugador` permitía a un miembro cambiar cualquier
   subcampo de su entrada en `players`, incluido `isSpectator`. Un espectador podía ponerse
   `isSpectator: false` y colarse como jugador activo sin pasar por el alta controlada (rompiendo la
   invariante de asiento/apuesta).
2. **UI — `room_page.dart`:** el botón «Iniciar apuestas» aparecía duplicado en `_BarraSala` y en
   `_FaseEspera` durante la fase `waiting`.
3. **Robustez — `room_page.dart`:** el botón «Salir de la sala» de `_FaseResultados` llamaba `salir()`
   sin `try-catch`; un fallo de red dejaba la pantalla congelada sin feedback.
4. **Limpieza — `room_page.dart`:** `onAccion: (a) => onAccion(a)` (lambda redundante).
5. **Limpieza — `firestore_sala_repository.dart`:** `_proximoAsiento` devolvía `asientos.length`
   (índice inválido) cuando los 6 asientos estaban llenos, en vez de fallar explícito.

**Corrección:** `soloActualizaSuJugador` ahora exige que `isSpectator` y `seat` no cambien (solo se
puede tocar apuesta/ready/connected). Se elimina el botón duplicado (la acción queda solo en
`_FaseEspera`; la barra muestra siempre el código de invitación). El botón «Salir» de resultados se
envuelve en `try-catch` con aviso. `onAccion` se pasa directo. `_proximoAsiento` lanza `StateError` si
no hay asientos. Reglas validadas con el emulador de Firestore.

**Limitación conocida (no corregida):** `seUneSolo` usa `players.size()` (incluye espectadores) en vez
del recuento de activos; arreglarlo en reglas requeriría iterar el mapa (no soportado). El impacto es
solo restrictivo (no un agujero), anotado para revisión futura.

**Aprendizaje:** al mergear un PR con review automático, esperar a que el bot termine de comentar el
último commit antes de hacer merge; los comentarios que llegan en paralelo al merge se pierden si no se
revisan después. En reglas de Firestore, restringir *qué subcampos* puede cambiar un usuario (no solo
*qué entrada*) es clave cuando esos subcampos definen privilegios (rol, asiento).
