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
- Si la banca llega a $0, se ofrece un **préstamo de $500** para seguir jugando.

## Modelo de datos tocado

Ninguno todavía. En la Fase 2 el estado es **local en memoria** (no se persiste). La persistencia del
saldo llega en la Fase 3 (auth + wallet) — ver [`../arquitectura/modelo-datos.md`](../arquitectura/modelo-datos.md).

## Estructura del código

```
core/theme/
├── temas.dart            ← 4 paletas (Clásico/Noche/Rubí/Oscuro) + ColoresTapete (ThemeExtension)
└── tema_provider.dart    ← provider del tema activo (Riverpod Notifier)

features/game/
├── domain/               ← (Fase 1) lógica pura: cartas, reglas, estrategia, modelos
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

Ninguna. En el juego solo todo corre en el cliente. El reparto/resolución en servidor llega con el
multijugador (Fase 5) por anti-trampa.

## Casos borde

- **Sin saldo** (banca ≤ 0 tras una ronda) → se muestra el botón de préstamo en vez de "Nueva mano".
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
