# Feature: Bono diario con racha

> Sub-PR **10b** de la Fase 10 del [plan maestro](../plans/00-app-multiplataforma.md). Detalle en
> [`../plans/02-perfil-progresion-y-leaderboards.md`](../plans/02-perfil-progresion-y-leaderboards.md).

## Propósito

Enganche de retención: el jugador reclama una recompensa **una vez al día**, y reclamar en **días
consecutivos** aumenta la racha y la recompensa. Sirve también de recarga cuando el saldo del juego solo
llega a $0.

## Reglas de negocio

- **Anti-trampa server-side:** la Cloud Function `claimDailyBonus` acredita el bono; el cliente no puede
  escribir `balance`, `dailyStreak` ni `lastDailyBonusDay` (`firestore.rules`).
- **Una vez por día calendario (UTC):** si ya se reclamó hoy → error `failed-precondition`.
- **Racha:** si el último reclamo fue **ayer**, la racha sube (+1); si hubo un hueco (o es el primero),
  vuelve a **1**. La racha del leaderboard (Fase 10a) es independiente de esta.
- **Recompensa creciente:** día 1 = 500, +100 por día consecutivo, **tope en el día 7 = 1100**
  (`montoPorRacha`, espejo en `functions/src/dailyBonus.ts` ↔ `wallet/domain/bono_diario.dart`).
- **Compatibilidad:** cuentas previas a la Fase 10b solo tienen el timestamp `lastDailyBonus`; el día se
  deriva de él hasta que exista `lastDailyBonusDay`.

## Modelo de datos tocado

`users/{uid}` (ver [`../arquitectura/modelo-datos.md`](../arquitectura/modelo-datos.md)):
`dailyStreak` (int, 🔒) y `lastDailyBonusDay` (string `YYYY-MM-DD`, 🔒), además del ya existente
`lastDailyBonus` (timestamp). Cada reclamo añade una transacción `bonus_daily`.

## Estructura del código

```
features/wallet/
├── domain/bono_diario.dart        ← montoPorRacha + ResultadoBonoDiario + EstadoBonoDiario
├── data/firestore_wallet_repository.dart  ← reclamarBonoDiario() + estadoBonoStream()
└── presentation/
    ├── wallet_provider.dart        ← estadoBonoProvider
    └── bono_diario_page.dart       ← racha, recompensa del día y botón reclamar
```

Soporte: `core/utils/semana.dart` (`idDiaUtc`), ruta `/bono`, acceso desde `barra_estado.dart`. El botón
de recarga del juego solo (`controlador_juego.pedirPrestamo`) usa el mismo bono.

## Cloud Functions relacionadas

- **`claimDailyBonus`** (`functions/src/dailyBonus.ts`): valida el día dentro de la transacción, calcula
  racha y monto, actualiza `balance`/`dailyStreak`/`lastDailyBonusDay` y registra la transacción.
  Devuelve `{ balance, amount, streak }`.

## Casos borde

- **Cuenta nueva / racha rota** → al reclamar, racha = 1 (monto base).
- **Reclamo en días consecutivos** → racha y recompensa crecen hasta el tope (día 7).
- **Cambio de día en el límite de medianoche UTC** → cliente y servidor usan `idDiaUtc` (UTC), así
  coinciden en si el bono está disponible.
- **Cuenta legacy con solo `lastDailyBonus`** → el día se deriva del timestamp (no permite doble reclamo
  el mismo día tras la migración).

## Cómo probarlo

- **Tests automáticos** (`flutter test` → `test/bono_diario_test.dart`): `montoPorRacha` (base, crecimiento,
  tope, racha ≤ 0) y `EstadoBonoDiario.montoAlReclamar`.
- **Prueba manual:** abrir `/bono`, reclamar (sube el saldo y la racha); reintentar el mismo día →
  "vuelve mañana".

## Pendiente de la Fase 10

- **10c** — misiones diarias/semanales.
