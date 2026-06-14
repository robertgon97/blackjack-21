# Feature: Misiones diarias y semanales

> Sub-PR **10c** de la Fase 10 del [plan maestro](../plans/00-app-multiplataforma.md), que **cierra** la
> fase. Detalle en [`../plans/02-perfil-progresion-y-leaderboards.md`](../plans/02-perfil-progresion-y-leaderboards.md).

## Propósito

Enganche y retención: objetivos con recompensa que se reinician cada **día** y cada **semana** (p. ej.
"gana 3 manos hoy", "haz un blackjack", "juega 50 manos esta semana"). Al completarlas, el jugador
**reclama** la recompensa.

## Reglas de negocio

- **Anti-trampa server-side:** el progreso lo acumula **solo** `playerAction` en
  `users/{uid}/progreso/{periodo}`; la recompensa la paga **solo** `claimMission`. El cliente no escribe
  ni el progreso ni el saldo (`firestore.rules`). **Solo el multijugador** suma progreso.
- **Periodos:** las diarias usan el día UTC (`idDiaUtc`), las semanales la semana ISO (`idSemanaIso`).
  Al cambiar el periodo, el progreso arranca de cero (documento nuevo).
- **Reclamo idempotente:** `claimMission` valida que el progreso ≥ meta y que la misión no esté ya en
  `reclamadas`; si no, devuelve error. Reclamar dos veces no paga dos veces.
- **Catálogo (espejo `functions/src/misiones.ts` ↔ `misiones/domain/mision.dart`):**

| id | tipo | meta | recompensa |
|----|------|------|-----------|
| `d_jugar` | diaria | 5 manos jugadas | 100 |
| `d_ganar` | diaria | 3 manos ganadas | 150 |
| `d_blackjack` | diaria | 1 blackjack | 200 |
| `s_jugar` | semanal | 50 manos jugadas | 500 |
| `s_ganar` | semanal | 20 manos ganadas | 700 |
| `s_ganancia` | semanal | 2000 de ganancia neta | 1000 |

## Modelo de datos tocado

`users/{uid}/progreso/{periodo}` (ver [`../arquitectura/modelo-datos.md`](../arquitectura/modelo-datos.md)):
`{ manosJugadas, ganadas, blackjacks, gananciaNeta, reclamadas: string[] }`. Cada reclamo añade una
transacción `mission_reward` (nuevo `TipoTransaccion.misionRecompensa`).

## Estructura del código

```
features/misiones/
├── domain/
│   ├── mision.dart            ← catálogo + Mision/TipoMision/MetricaMision
│   ├── progreso_periodo.dart  ← ProgresoPeriodo + EstadoMision (derivado)
│   └── i_misiones_repository.dart
├── data/firestore_misiones_repository.dart  ← progresoStream + reclamarMision
└── presentation/
    ├── misiones_provider.dart  ← progresoDiarioProvider / progresoSemanalProvider
    └── misiones_page.dart      ← secciones diarias/semanales con progreso y reclamo
```

Soporte: ruta `/misiones`, acceso desde `barra_estado.dart`, tipo `mission_reward` en el historial.

## Cloud Functions relacionadas

- **`playerAction`**: incrementa `users/{uid}/progreso/{díaUTC}` y `.../{semanaISO}` con
  `manosJugadas`/`ganadas`/`blackjacks`/`gananciaNeta` de la ronda.
- **`claimMission`** (`functions/src/misiones.ts`): valida progreso e idempotencia y paga la recompensa.

## Casos borde

- **Misión no completada** → `failed-precondition`; el botón solo aparece cuando `reclamable`.
- **Reclamo doble** → `already-exists` (la misión ya está en `reclamadas`).
- **Cambio de día/semana** → documento de progreso nuevo; las misiones vuelven a 0 y a reclamables.
- **`gananciaNeta` negativa** → el progreso de `s_ganancia` puede bajar; se valida ≥ meta al reclamar.

## Cómo probarlo

- **Tests automáticos** (`flutter test` → `test/mision_test.dart`): catálogo (ids únicos, paridad con TS),
  `ProgresoPeriodo.fromMap` y `EstadoMision` (completada/reclamable/reclamada/fracción).
- **Prueba manual** (Function desplegada + multijugador): jugar hasta cumplir una misión, abrir
  `/misiones`, reclamar (sube el saldo); reintentar → "ya reclamaste".
