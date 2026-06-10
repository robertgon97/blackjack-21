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
