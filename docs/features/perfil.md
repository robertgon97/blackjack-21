# Feature: Perfil y estadísticas de juego

> Fase 8 del [plan maestro](../plans/00-app-multiplataforma.md). Detalle del bloque de producto en
> [`../plans/02-perfil-progresion-y-leaderboards.md`](../plans/02-perfil-progresion-y-leaderboards.md).

## Propósito

Dar al jugador una pantalla de perfil de verdad: su identidad (avatar y nombre editables, código de
invitación, tipo de cuenta, "miembro desde"), su saldo con acceso al historial de movimientos, y sus
**estadísticas de juego** acumuladas (manos, % de victoria, blackjacks, rachas, totales apostado/ganado).

## Reglas de negocio

- **Solo el multijugador alimenta las estadísticas oficiales.** El modo solo es client-side y sería
  trampeable, así que **no** cuenta para las stats (decisión anti-trampa del plan).
- Las stats las escribe **exclusivamente la Cloud Function** `playerAction` al resolver la ronda, en la
  misma transacción que actualiza el saldo. El cliente **nunca** las escribe (igual que `balance`).
- **Racha:** se calcula por **ronda**, no por mano. Una ronda ganada (`win`/`blackjack`) incrementa la
  racha; un empate (`push`) la mantiene; una derrota o rendición (`lose`/`surrender`) la reinicia a 0.
- **Manos jugadas:** cada mano de un split cuenta por separado.
- **Ganadas** incluye los blackjacks (un blackjack es una victoria, y además se cuenta aparte en
  `blackjacks`).
- El usuario puede editar **solo** su `displayName` y `avatar`; el resto del documento (saldo,
  `isAnonymous`, etc.) está protegido por reglas.

## Modelo de datos tocado

`users/{uid}` (ver [`../arquitectura/modelo-datos.md`](../arquitectura/modelo-datos.md)):

- **`stats`** (nuevo, objeto escrito por Functions): `manosJugadas`, `ganadas`, `perdidas`, `empates`,
  `blackjacks`, `mayorGanancia`, `rachaActual`, `mejorRacha`, `totalApostado`, `totalGanado`.
- `displayName`, `avatar` — editables por el dueño.
- `createdAt` — leído como "miembro desde".

`firestore.rules`: `stats` se añadió a la lista de campos que `noTocaCamposProtegidos()` impide editar
desde el cliente.

## Estructura del código

```
features/profile/
├── domain/
│   ├── estadisticas.dart          ← modelo Estadisticas (+ fromMap, porcentajeVictoria)
│   └── i_profile_repository.dart  ← interfaz (sin Firebase)
├── data/
│   └── firestore_profile_repository.dart  ← lee users/{uid}.stats
└── presentation/
    ├── profile_provider.dart      ← profileRepositoryProvider + estadisticasProvider
    └── perfil_page.dart           ← pantalla /perfil (cabecera editable, saldo, grilla de stats)
```

Soporte fuera de la feature:
- `auth/domain/perfil_usuario.dart` — campo nuevo `creadoEn` ("miembro desde").
- `auth/data/firebase_auth_repository.dart` — `actualizarPerfil()` (escribe Firestore + refleja en Auth
  para forzar el re-emit de `perfilStream`).
- `core/router/app_router.dart` — ruta `/perfil`.
- `core/utils/formato.dart` — `fechaCorta()`.
- Accesos: botón en `game/presentation/widgets/barra_estado.dart` y entrada en `panel_ajustes.dart`.

## Dependencias externas

Ninguna nueva. Solo `cloud_firestore` (ya presente).

## Cloud Functions relacionadas

- **`playerAction`** (`functions/src/playerAction.ts`): al resolver la ronda acumula `users/{uid}.stats`
  mediante la función pura `acumularStats()` (`functions/src/blackjack.ts`), espejo del modelo Dart.
  Ver [`../arquitectura/seguridad.md`](../arquitectura/seguridad.md).

## Casos borde

- **Cuenta anterior a la Fase 8 / sin partidas multijugador** → `users/{uid}` sin `stats`:
  `Estadisticas.fromMap(null)` devuelve todo en cero y la UI muestra un mensaje de "todavía no jugaste".
- **`createdAt` ausente** (perfil mínimo por fallo de red, o justo tras crear la cuenta con
  `serverTimestamp` aún sin releer) → no se muestra el chip "miembro desde".
- **Editar solo el avatar sin cambiar el nombre** → `updatePhotoURL` fuerza el re-emit de `perfilStream`,
  así que la cabecera se refresca igual.
- **Pérdida que llevaría el saldo a negativo** → el saldo se acota a 0 (ya existente); las stats reflejan
  la derrota igualmente.

## Cómo probarlo

- **Tests automáticos** (`flutter test` → `test/estadisticas_test.dart`): `Estadisticas.fromMap` tolerante
  a mapas nulos/parciales y a enteros llegados como `double`; `porcentajeVictoria` (incluida la división
  por cero).
- **Prueba manual** (requiere la Function desplegada y dos jugadores):
  1. Entrar a una sala multijugador y jugar varias rondas.
  2. Abrir `/perfil` (icono de perfil en la barra o "Mi perfil" en ajustes) y comprobar que manos,
     victorias, blackjacks y rachas se actualizan tras cada ronda resuelta.
  3. Editar nombre y avatar; verificar que la cabecera se refresca y que el cambio persiste al reabrir.
