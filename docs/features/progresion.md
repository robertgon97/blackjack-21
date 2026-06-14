# Feature: Progresión (niveles/XP + logros)

> Fase 9 del [plan maestro](../plans/00-app-multiplataforma.md). Detalle del bloque de producto en
> [`../plans/02-perfil-progresion-y-leaderboards.md`](../plans/02-perfil-progresion-y-leaderboards.md).
> Construye sobre las estadísticas de la [Fase 8](perfil.md).

## Propósito

Dar sensación de avance: el jugador acumula **XP** al jugar (sube de **nivel**) y desbloquea **logros**
por hitos (primera victoria, blackjack, rachas, manos jugadas, gran ganancia, saldo alto). Migra el
`legacy-web/js/stats.js` (`NIVELES`, `LOGROS`) al dominio actual.

## Reglas de negocio

- **Anti-trampa server-side:** tanto la XP como los logros los escribe **solo** la Cloud Function
  `playerAction` al resolver la ronda, en la misma transacción que `balance` y `stats`. El cliente no
  los escribe (ver `firestore.rules`). **Solo el multijugador** alimenta la progresión.
- **XP por ronda:** `+10` por mano jugada, `+15` extra por mano ganada, `+40` extra por blackjack
  (`xpDeRonda` en `functions/src/blackjack.ts`).
- **Nivel:** modelo **híbrido** — el nivel se **deriva de la XP acumulada** (no de la banca como el
  legacy). Escala de 6 niveles con los nombres del legacy (Novato → Leyenda); umbrales en
  `profile/domain/niveles.dart`. **No se almacena**, se calcula en el cliente.
- **Logros:** se evalúan server-side con las stats + el saldo resultante y se agregan a `users/{uid}.logros`
  con `arrayUnion` (idempotente: nunca se repiten ni se quitan).

### Catálogo de logros (Fase 9)

| id | nombre | condición |
|----|--------|-----------|
| `primera` | 🎉 Primera victoria | `ganadas >= 1` |
| `bj` | 🃏 ¡Blackjack! | `blackjacks >= 1` |
| `racha3` | 🔥 3 seguidas | `mejorRacha >= 3` |
| `racha5` | 🔥🔥 5 seguidas | `mejorRacha >= 5` |
| `veterano` | 🎖️ Veterano | `manosJugadas >= 50` |
| `centenario` | 💯 Centenario | `manosJugadas >= 100` |
| `granGanancia` | 💰 Gran ganancia | `mayorGanancia >= 500` (una ronda) |
| `ricachon` | 💎 Ricachón | `balance >= 5000` |

## Modelo de datos tocado

`users/{uid}` (ver [`../arquitectura/modelo-datos.md`](../arquitectura/modelo-datos.md)):
- `stats.xp` (nuevo) — XP acumulada.
- `logros` (nuevo, `array<string>`) — IDs desbloqueados (escritos con `arrayUnion`).

`firestore.rules`: `logros` añadido a `noTocaCamposProtegidos()` (junto a `stats`).

## Estructura del código

```
features/profile/
├── domain/
│   ├── estadisticas.dart   ← + campo xp
│   ├── niveles.dart        ← Nivel, escala, progresoDeXp() (lógica pura)
│   └── logros.dart         ← catálogo (metadata) + logroPorId()
├── data/
│   └── firestore_profile_repository.dart  ← + logrosStream()
└── presentation/
    ├── profile_provider.dart  ← + logrosProvider
    └── perfil_page.dart       ← tarjeta de nivel + galería de logros
```

- **Toast de logro**: en `lib/app.dart`, un `ref.listen(logrosProvider)` global compara los IDs previos
  con los nuevos y muestra un `SnackBar` (vía un `scaffoldMessengerKey` global) solo para los recién
  desbloqueados; los históricos no disparan aviso al abrir la app.

## Cloud Functions relacionadas

- **`playerAction`** (`functions/src/playerAction.ts`): acumula `stats.xp` (`acumularStats` →
  `xpDeRonda`) y evalúa logros (`evaluarLogros` en `functions/src/logros.ts`), persistiendo ambos en la
  transacción de resolución. Ver [`../arquitectura/seguridad.md`](../arquitectura/seguridad.md).

> **Duplicación TS ↔ Dart:** los **ids y condiciones** de los logros viven en `functions/src/logros.ts`
> (evaluación anti-trampa); la **metadata** (nombre, emoji, descripción) en `profile/domain/logros.dart`
> (galería). Los ids deben coincidir; un test de paridad fija la lista esperada en Dart.

## Casos borde

- **Cuenta sin XP / sin logros** → barra en Novato (0 XP) y galería con todo bloqueado (🔒 + gris).
- **Nivel máximo (Leyenda)** → barra al 100 %, sin "faltan X XP".
- **Logro con id desconocido** (Function más nueva que el cliente) → `logroPorId` devuelve `null` y se
  ignora en la galería y en el toast (no rompe).
- **Varios logros en una ronda** → se encolan varios toasts; todos se agregan con `arrayUnion`.

## Cómo probarlo

- **Tests automáticos** (`flutter test`):
  - `test/niveles_test.dart` — `progresoDeXp` (umbrales, fracción, XP negativa, nivel máximo).
  - `test/logros_test.dart` — integridad del catálogo, ids únicos, paridad con `logros.ts`, `logroPorId`.
  - `test/estadisticas_test.dart` — el campo `xp` se parsea (y default 0).
- **Prueba manual** (Function desplegada + multijugador):
  1. Jugar rondas y ver subir la XP / la barra de nivel en `/perfil`.
  2. Desbloquear un logro (p. ej. ganar la primera mano) → aparece el toast y la tarjeta pasa a color.
