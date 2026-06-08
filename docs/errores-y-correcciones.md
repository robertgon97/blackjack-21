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
