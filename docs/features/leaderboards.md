# Feature: Leaderboards semanales

> Fase 10 del [plan maestro](../plans/00-app-multiplataforma.md). Detalle en
> [`../plans/02-perfil-progresion-y-leaderboards.md`](../plans/02-perfil-progresion-y-leaderboards.md).
> La Fase 10 se entrega en sub-PRs: **10a (esta ficha)** leaderboards + top de amigos; 10b bono diario
> con racha; 10c misiones. Construye sobre las stats de la [Fase 8](perfil.md).

## Propósito

Competencia y retención: un ranking **semanal** (se reinicia cada semana) por tres métricas —ganancia
neta, manos ganadas y mejor racha— con **top global**, **top entre amigos** y la **posición del usuario**.

## Reglas de negocio

- **Anti-trampa server-side:** las entradas las escribe **solo** `playerAction` al resolver la ronda,
  en su misma transacción (junto a `balance`/`stats`/`logros`). El cliente solo lee
  (`firestore.rules`). **Solo el multijugador** alimenta el ranking.
- **Periodo semanal:** el id de periodo es la **semana ISO-8601** (`YYYY-Www`), calculada en UTC para no
  depender de la zona del dispositivo (`core/utils/semana.dart` ↔ `functions/src/semana.ts`). El periodo
  "se abre" implícitamente al cambiar la semana; los antiguos se purgan (retención de 8 semanas) con la
  scheduled function `purgarLeaderboards`.
- **Métricas (acumuladas en la semana):** `gananciaNeta` (suma de deltas, puede ser negativa),
  `manosGanadas` (suma), `mejorRacha` (máximo de la racha **propia de la semana**). La racha del
  leaderboard se rastrea aparte de la racha global de `stats` (que no se reinicia por semana): se guarda
  `rachaActualSemana` en la entrada y arranca en 0 cada periodo, evitando heredar la racha de la semana
  anterior.

## Modelo de datos tocado

`leaderboards/{periodo}/entries/{uid}` — ver [`../arquitectura/modelo-datos.md`](../arquitectura/modelo-datos.md):
`{ uid, displayName, avatar, gananciaNeta, manosGanadas, mejorRacha, updatedAt }`.

`firestore.rules`: `leaderboards/{periodo}` y su subcolección `entries` son `read: if autenticado()`,
`write: if false`. No requiere índices compuestos (orderBy de campo único; el top de amigos lee por id).

## Estructura del código

```
features/leaderboards/
├── domain/
│   ├── entrada_ranking.dart        ← EntradaRanking + enum MetricaRanking
│   └── i_leaderboard_repository.dart
├── data/
│   └── firestore_leaderboard_repository.dart  ← periodo = semana ISO actual
└── presentation/
    ├── leaderboard_provider.dart   ← topGlobal/topAmigos/miEntrada/miPosicion
    └── leaderboard_page.dart       ← 3 pestañas × toggle global/amigos + tu posición
```

Soporte: `core/utils/semana.dart` (id de semana ISO), ruta `/leaderboard` en `app_router.dart`, acceso
desde `barra_estado.dart`.

## Cloud Functions relacionadas

- **`playerAction`** (`functions/src/playerAction.ts`): lee la entrada del periodo en la fase de reads y,
  al resolver, acumula `gananciaNeta`/`manosGanadas` y el `max` de `mejorRacha` por jugador.
- **`purgarLeaderboards`** (`functions/src/leaderboard.ts`): scheduled (`onSchedule`, lunes 03:00
  America/Sao_Paulo) que purga los periodos con más de 8 semanas (retención).

## Casos borde

- **Semana sin partidas** → la colección del periodo no existe; la UI muestra "nadie ha jugado".
- **Usuario sin entrada esta semana** → no se muestra su posición global (no juega aún).
- **Ganancia neta negativa** → se ordena igual (puede quedar al fondo del ranking).
- **Posición global** → `count()` agregado de Firestore (entradas con valor estrictamente mayor + 1); no
  descarga documentos.
- **Top de amigos** → lectura puntual por id de cada amigo aceptado (+ uno mismo), ordenado en cliente;
  evita el operador `in` y el índice compuesto.

## Cómo probarlo

- **Tests automáticos** (`flutter test`):
  - `test/semana_test.dart` — id de semana ISO (casos borde de fin/inicio de año).
  - `test/entrada_ranking_test.dart` — parsing y selección de métrica.
- **Prueba manual** (Function desplegada + multijugador): jugar rondas con ≥2 cuentas y ver el ranking
  poblarse en `/leaderboard`; cambiar entre métricas y entre Global/Amigos; comprobar la posición propia.

## Resto de la Fase 10

- ✅ **10b** — bono diario con racha ([`bono-diario.md`](bono-diario.md)).
- ✅ **10c** — misiones diarias/semanales ([`misiones.md`](misiones.md)).
