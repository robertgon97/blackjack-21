# Feature: Juego solo (jugador vs crupier) — UI en Flutter

> Fase 2 del [plan maestro](../plans/00-app-multiplataforma.md). Construye la UI del juego de un
> jugador sobre la lógica de dominio ya migrada y probada en la Fase 1.

## Propósito

Permite jugar una partida completa de Blackjack contra el crupier (el sistema) desde cualquier
plataforma: apostar con fichas, recibir cartas, decidir (pedir/plantarse/doblar/dividir/rendirse),
tomar seguro, ver el resultado y el saldo, con 4 temas visuales y ayudas de aprendizaje.

## Reglas de negocio

Fuente: [`../reglas-negocio/reglas-del-juego.md`](../reglas-negocio/reglas-del-juego.md). La UI **no
reimplementa** reglas; solo orquesta las funciones puras de `game/domain/`.

- Fases del flujo: **apuestas → (seguro si el crupier muestra As) → turno del jugador → turno del
  crupier → resultado**.
- Apuesta entre `apuestaMin` y `apuestaMax`; no puede exceder la banca. Fichas de $10/$25/$50/$100.
- Las jugadas extra (doblar/dividir/rendirse) se habilitan según `opcionesActuales(...)` del dominio.
- El crupier juega automáticamente con `debePedirCrupier(...)` (regla H17 configurable).
- Resolución y pagos con `resolverMano(...)`: blackjack natural paga `pagoBlackjack` (3:2 o 6:5);
  seguro paga 2:1 si el crupier tiene blackjack.
- El saldo de la banca es el **balance real del usuario** (`users/{uid}.balance`): se lee al entrar y
  se **persiste tras cada ronda** mediante la Cloud Function `resolveSoloRound` (no se puede escribir
  desde el cliente — campo protegido por las reglas anti-trampa).

## Modelo de datos tocado

`users/{uid}.balance` (lectura vía `saldoStream`; escritura **solo** vía la Function `resolveSoloRound`)
y la subcolección `users/{uid}/transactions` (registro de cada ronda). Ver
[`../arquitectura/modelo-datos.md`](../arquitectura/modelo-datos.md).

> **Persistencia del saldo (issue #30):** hasta esta corrección la banca vivía solo en memoria
> (arrancaba en 1000 y no se guardaba), así que al reiniciar la app se perdía. Ahora el juego solo lee
> el balance real y lo actualiza server-side. La **recarga** cuando el saldo llega a $0 es un **bono
> diario** de $500 (una vez cada 24 h) acreditado por la Function `claimDailyBonus` (sustituye al
> antiguo "préstamo" local, que inflaba un saldo que el servidor no reconocía).

## Estructura del código

```
core/theme/
├── temas.dart            ← 4 paletas (Clásico/Noche/Rubí/Oscuro) + ColoresTapete (ThemeExtension)
└── tema_provider.dart    ← provider del tema activo (Riverpod Notifier)

features/game/
├── domain/               ← (Fase 1) lógica pura: cartas, reglas, estrategia, modelos
│   └── i_resultado_solo_repository.dart  ← interfaz: persistir el resultado de la ronda
├── data/
│   └── cloud_resultado_solo_repository.dart  ← impl: llama la Function resolveSoloRound
└── presentation/
    ├── estado_juego.dart       ← estado inmutable (FaseJuego, SignoResultado) + copyWith
    ├── controlador_juego.dart  ← Notifier: orquesta dominio + shoe + dinero + animaciones
    ├── pantalla_juego.dart     ← pantalla principal (tapete)
    └── widgets/
        ├── carta_widget.dart         ← naipe (cara o reverso)
        ├── zona_crupier_widget.dart  ← mano del crupier + puntaje
        ├── mano_jugador_widget.dart  ← una o varias manos (splits) con resalte de la activa
        ├── panel_apuestas.dart       ← fichas + repartir
        ├── botones_accion.dart       ← pedir/plantarse/doblar/dividir/rendirse
        ├── barra_estado.dart         ← banca, en juego, conteo, selector de tema, ajustes
        └── panel_ajustes.dart        ← edita ConfigJuego (reglas de la mesa)
```

Responsabilidades clave:
- `domain/...` — reglas puras (no cambian en esta fase).
- `presentation/controlador_juego.dart` — único lugar que muta el estado; traduce el flujo de
  `legacy-web/js/juego.js` a un `Notifier` sin estado global ni DOM. El `Shoe` vive como campo
  privado del controlador (mutable); el resto del estado es inmutable.
- `presentation/widgets/...` — solo pintan y disparan métodos del controlador.

## Dependencias externas

- `flutter_riverpod` (gestión de estado). Se usa con `Notifier` escrito a mano (sin `build_runner`).

## Cloud Functions relacionadas

- **`resolveSoloRound`** (`functions/src/soloRound.ts`): recibe la ronda terminada (manos del jugador,
  mano del crupier, seguro, config), **revalida el resultado** con la lógica compartida
  `functions/src/blackjack.ts` (espejo de `cartas.dart`/`reglas.dart`) sin confiar en el cliente,
  comprueba que la apuesta no supera el saldo y que el crupier jugó según las reglas, y actualiza
  `users/{uid}.balance` + registra la transacción. Ver
  [`../arquitectura/seguridad.md`](../arquitectura/seguridad.md).
- **`claimDailyBonus`** (`functions/src/dailyBonus.ts`): acredita el **bono diario** de $500 una vez
  cada 24 h (control de cooldown sobre `users/{uid}.lastDailyBonus`, campo protegido en
  `firestore.rules`). Es la recarga cuando el saldo llega a $0.

> **Limitación conocida (Opción B):** el reparto sigue siendo client-side, así que el cliente elige las
> cartas. La Function valida las *reglas* (no puedes ganar con cartas perdedoras ni plantar al crupier
> antes de 17), pero el reparto server-side completo (shoe oculto, como el multijugador) queda como
> hardening futuro.

## Casos borde

- **Sin saldo** (banca ≤ 0 tras una ronda) → botón "Reclamar bono diario ($500)": acredita el bono vía
  `claimDailyBonus` si no se reclamó en las últimas 24 h; si está en cooldown, avisa cuándo volver.
- **Fallo de red al guardar** → la ronda se muestra igual; se avisa que el saldo no se guardó y se
  reconcilia con Firestore al reabrir (la banca local no es autoritativa).
- **Blackjack natural** (21 con 2 cartas, sin split ni doble) → resuelve de inmediato y paga 3:2/6:5.
- **Split de ases** → cada mano recibe **una sola carta** y se planta automáticamente.
- **Crupier con As** → se ofrece seguro antes del turno; solo si la banca cubre la mitad de la apuesta.
- **Penetración del shoe** (~25% restante) → rebaraja automáticamente al repartir.
- **Cambio de reglas** (ajustes) → bloqueado durante una ronda; cambiar el nº de barajas regenera el shoe.

## Cómo probarlo

- Tests automáticos (`flutter test`): la lógica de dominio ya está cubierta (Fase 1) y es la que
  decide reglas, pagos y opciones. La capa de presentación (UI + controlador) se verifica de forma
  manual en esta fase; los tests de widget llegarán cuando se estabilice el flujo.
- Prueba manual (`flutter run -d chrome`): apostar → repartir → jugar una mano, probar doblar/dividir
  con pares, rendirse, tomar seguro con As del crupier, cambiar entre los 4 temas y editar ajustes.
