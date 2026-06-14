# CLAUDE.md — Guía del proyecto Blackjack 21 (Flutter)

> **Regla de oro:** antes de tocar una feature, lee su ficha en [`docs/features/`](docs/features/)
> y las reglas de negocio en [`docs/reglas-negocio/`](docs/reglas-negocio/).
> La carpeta [`docs/`](docs/README.md) es la **fuente de verdad** del proyecto.

## Reglas de colaboración

- **Aprobación antes de commitear:** prepara los cambios y explícalos, pero **no hagas `git push`
  sin confirmación explícita del usuario**. Muestra el commit y espera el "sí" o los ajustes.
- **Registro de errores:** si cometes un error (código incorrecto, regresión, suposición equivocada),
  documéntalo en [`docs/errores-y-correcciones.md`](docs/errores-y-correcciones.md) antes de
  corregirlo — fecha, qué falló, causa, corrección, aprendizaje.

## Qué es

App multiplataforma de Blackjack (21) con multijugador en tiempo real. Desarrollada en **Flutter**
(un solo codebase para Android, Web, Windows e iOS), respaldada por **Firebase**.

El juego JS original está archivado en [`legacy-web/`](legacy-web/).

## Cómo ejecutar y verificar

```bash
# Instalar dependencias
flutter pub get

# Correr la app
flutter run -d chrome       # web (recomendado para desarrollo)
flutter run -d windows      # escritorio Windows
flutter run -d <device>     # Android o iOS

# Calidad (lo que corre el CI)
dart format --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test

# Firebase local (cuando esté configurado en Fase 3+)
firebase emulators:start

# Build de producción
flutter build web --release --base-href /blackjack-21/
flutter build apk --release
```

## Arquitectura

### Capas (sin cruzar en dirección contraria)

```
presentation  →  domain  ←  data
(widgets,          (lógica     (Firestore,
 Riverpod)          pura)       Firebase Auth)
```

La capa `domain` **nunca** importa Flutter, Firebase ni widgets.
La capa `data` implementa las interfaces de `domain`.

### Módulos de `lib/`

```
lib/
├── main.dart               ← entrada (solo llama runApp)
├── app.dart                ← widget raíz + MaterialApp
├── core/
│   ├── theme/              ← 4 temas (ThemeData con ColorScheme)
│   ├── router/             ← go_router + deep links (/join/CODIGO)
│   ├── widgets/            ← Toast, AppModal, LoadingButton, Avatar
│   └── utils/              ← formateo de dinero/fechas (puro)
└── features/
    ├── game/
    │   ├── domain/         ← LÓGICA PURA migrada del JS (sin Flutter ni Firebase)
    │   │   ├── modelos.dart    Carta, Mano, ConfigJuego, ResultadoMano
    │   │   ├── cartas.dart     calcularPuntos, infoMano, Shoe, Hi-Lo
    │   │   ├── estrategia.dart consejoEstrategia → Jugada enum
    │   │   └── reglas.dart     resolverMano, debePedirCrupier, opcionesActuales
    │   ├── data/           ← GameRepository (Firestore games/{id})
    │   └── presentation/   ← widgets del tapete, cartas, botones
    ├── auth/               domain · data · presentation
    ├── wallet/             domain · data · presentation  (HistorialPage)
    ├── friends/            domain · data · presentation  (FriendsPage, TransferPage)
    ├── rooms/              domain · data · presentation  (LobbyPage, RoomPage)
    ├── comms/              ← chat + voz + cámara
    │   ├── domain/
    │   │   ├── servicio_comunicacion.dart  ← INTERFAZ (intercambiable)
    │   │   └── modelos.dart               MensajeChat, ParticipanteMedia
    │   ├── data/
    │   │   ├── livekit_comunicacion.dart  ← impl. LiveKit (intercambiable)
    │   │   └── chat_repository.dart       rooms/{id}/chat en Firestore
    │   └── presentation/   PanelChat, RejillaVideo, ControlesMedia
    └── profile/            domain · data · presentation
```

## Documentación viva (`docs/`)

| Carpeta | Contenido |
|---------|-----------|
| `docs/plans/` | Plan maestro de fases (`00-app-multiplataforma.md`) |
| `docs/arquitectura/` | Visión general, modelo de datos Firestore, seguridad |
| `docs/reglas-negocio/` | Reglas del juego, créditos, salas, social |
| `docs/features/` | Una ficha por feature (usando `_plantilla-feature.md`) |

**Al cerrar cada fase:** crear/actualizar la ficha de feature y actualizar README.md + CLAUDE.md.

## Estado de Firebase

- Proyecto: `blackjack-21-app`
- Región Firestore: `southamerica-east1` (São Paulo)
- Reglas y índices: `firestore.rules` / `firestore.indexes.json` (ya desplegados)
- ✅ Plan **Blaze** activo (Cloud Functions en producción desde la Fase 4).
- ✅ Proveedores de Auth habilitados: Email/Password, Google, Anónimo.
- ✅ `flutterfire configure` ejecutado: `lib/firebase_options.dart` generado (web/Android/iOS/Windows).
- ✅ **Firma Android** + **Google Sign-In**: keystore y 4 GitHub Secrets configurados; huellas SHA
  registradas en Firebase (`google-services.json` con OAuth client de tipo 1).

## Tests

```bash
flutter test                           # corre los 85 tests de domain
flutter test --reporter=expanded       # con detalle de cada test
```

Los tests cubren solo la capa `domain` (lógica pura, sin Firebase ni widgets).
Para forzar cartas concretas, usa `Shoe(n, random: Random(semilla))`.

## Convenciones de código

- Comentarios, nombres y UI en **español** (con acentos correctos).
- Doc-comments `///` en español en cada API pública de `domain/`.
- Linter estricto: `strict-casts`, `strict-inference`, `strict-raw-types`.
- Modelos inmutables con `copyWith()` (se añadirá `freezed` en Fase 2).
- Providers de Riverpod: `StreamProvider` para datos Firestore en tiempo real.
- **No duplicar lógica entre capas:** si algo está en `domain`, `presentation` lo llama.

## CI/CD (GitHub Actions)

| Archivo | Disparador | Qué hace |
|---------|-----------|----------|
| `ci.yml` | push/PR a main | **Analyze & Test** (format + analyze --fatal-infos + test+coverage) y **Lint & Build Functions** (ESLint + tsc) |
| `deploy-web.yml` | push a main | build web → GitHub Pages |
| `deploy-firebase.yml` | push a main | 3 jobs en paralelo: Firestore (reglas+índices), **Functions** y Hosting |
| `build-artifacts.yml` | push a main + manual | APK **debug** (Android) + build **Windows** release (artefactos, 30 días) |
| `release.yml` | tag `v*` | **APK + AAB firmados** + iOS sin firma; versión dinámica desde el tag (`versionName`) y `run_number` (`versionCode`) |

> En GitHub Pages: Settings → Pages → Source → **"GitHub Actions"** (acción manual, una sola vez).

## Git / despliegue

- Repo: `robertgon97/blackjack-21`, rama `main`
- Auth: `gh auth switch --user robertgon97` si falla el push
- Flujo: `git add <archivos> && git commit -m "..." && git push`

## Gotchas aprendidos

1. **`domain` sin Flutter:** las funciones de `cartas.dart`, `estrategia.dart` y `reglas.dart`
   son puras (sin `import 'package:flutter/...'`). Si necesitas Flutter en ellas, estás en la
   capa equivocada.
2. **`resolverMano` con `esUnicaMano`:** en el JS original detectaba BJ con `manos.length === 1`
   (estado global). En Dart es un parámetro explícito para mantener la función pura.
3. **`probabilidadPasarse`:** recibe `List<Carta> restantes` en vez de acceder al `shoe` global.
   `Shoe.restantes` devuelve una vista inmutable para pasarla.
4. **`Shoe` con `Random` inyectable:** `Shoe(6, random: Random(semilla))` para tests deterministas.
5. **Linter `require_trailing_commas`:** en listas/params de más de una línea, coma final siempre.
6. **Comunicación en sala:** la interfaz `ServicioComunicacion` está en `comms/domain/`. Para
   cambiar de LiveKit a otro proveedor, crear nueva clase en `comms/data/`; la UI no cambia.
7. **Navegación principal (issue #67):** la `BarraEstado` del juego solo muestra datos (banca, en juego,
   conteo) + el botón ☰. El acceso a perfil/misiones/bono/ranking/multijugador/amigos, el tema y las
   reglas de la mesa viven en `MenuDrawer` (`game/presentation/widgets/menu_drawer.dart`), el `drawer`
   del `Scaffold` de `PantallaJuego`. Al añadir una sección nueva, enchúfala ahí (no en la barra).

## Pendiente (fases futuras)

> Los pendientes técnicos sueltos están documentados como issues de GitHub:
>
> - [#54](https://github.com/robertgon97/blackjack-21/issues/54) — App Check enforcement (hoy modo monitor).
> - [#55](https://github.com/robertgon97/blackjack-21/issues/55) — Warning KGP (bloqueado por `cloud_firestore`).
> - [#56](https://github.com/robertgon97/blackjack-21/issues/56) — Migrar modelos a `freezed` + `json_serializable`.
> - [#57](https://github.com/robertgon97/blackjack-21/issues/57) — Providers de Riverpod + ficha de feature de `comms`.

- **Fase 11 (siguiente):** monetización y pulido (anuncios, PWA, push). Hoja de ruta en
  [`docs/plans/01-firebase-observabilidad-y-crecimiento.md`](docs/plans/01-firebase-observabilidad-y-crecimiento.md)
  y [`docs/plans/00-app-multiplataforma.md`](docs/plans/00-app-multiplataforma.md).

> **Hecho en Fase 2:** las 4 paletas (`core/theme/temas.dart`) y la UI del juego solo con su
> controlador Riverpod (`features/game/presentation/`). Ficha:
> [`docs/features/juego-solo.md`](docs/features/juego-solo.md).
>
> **Hecho en Fase 3:** auth (email/Google/anónimo), perfil + saldo persistente en Firestore,
> historial de movimientos y `go_router` con guard de sesión (`core/router/app_router.dart`).
> Repos tras interfaz: `features/auth/`, `features/wallet/`. Ficha:
> [`docs/features/auth-y-saldo.md`](docs/features/auth-y-saldo.md).
>
> **Hecho en Fase 4:** sistema de amigos por código de invitación, gestión de solicitudes
> (enviar/aceptar/rechazar/cancelar), transferencias atómicas entre amigos vía Cloud Function
> `transferCredits`. Repos: `features/friends/`. Functions: `functions/src/transfers.ts`.
> Ficha: [`docs/features/social.md`](docs/features/social.md).
>
> **Hecho en Fase 3.5:** conversión de cuenta anónima → permanente (account linking) conservando el
> `uid`, con bono +500 idempotente vía Cloud Function `claimConversionBonus`
> (`functions/src/conversion.ts`). UI: `pantalla_conversion.dart` + `banner_conversion.dart`, ruta
> `/convertir`, y advertencia al cerrar sesión siendo anónimo (CU-5) en el panel de ajustes.
> `firestore.rules` protege `isAnonymous`/`conversionBonusGranted`. El despliegue es **automático
> al mergear a main** (workflow `deploy-firebase.yml` → jobs Firestore + Functions + Hosting; Blaze
> ya activo). Ficha: [`docs/features/conversion-cuenta.md`](docs/features/conversion-cuenta.md).
>
> **Hecho en Fase 5:** salas multijugador en tiempo real (`features/rooms/`). Reparto y resolución
> **server-side** anti-trampa vía Cloud Functions `startRound` y `playerAction`; el shoe vive oculto en
> `games/{id}/serverData/current` (`allow read: if false`). Flujo waiting→betting→playing→finished,
> reglas granulares por rol en `rooms`. Ficha: [`docs/features/rooms.md`](docs/features/rooms.md).
>
> **Hecho en Fase 6:** observabilidad base — Crashlytics (Android/iOS) + Analytics (Android/iOS/Web).
> Capa `core/telemetria/` con interfaz `IServicioTelemetria`, implementación Firebase y no-op para
> Windows/Linux. Hooks globales de error en `main.dart`, observer de navegación, toggle de privacidad
> en `PanelAjustes`, eventos de juego/sala/social. Issues abiertos: #18, #19, #20.
> Ficha: [`docs/features/observabilidad.md`](docs/features/observabilidad.md).
>
> **Hecho en Fase 7:** App Check (`core/app_check/`, mismo patrón que telemetría) en **modo monitor**:
> Play Integrity (Android), App Attest (iOS), reCAPTCHA v3 (Web), no-op en Windows; debug provider en
> desarrollo. Se activa *fire-and-forget* en `main.dart` (no `await`, para no bloquear `runApp`). El
> enforcement en Firestore/Functions queda pendiente (se activa en consola tras medir). Junto con esto
> se migró todo el **BoM de Firebase a la generación 4.x/6.x** (incluida la reescritura del login con
> `google_sign_in 7.x`: singleton + `initialize()` + `authenticate()`). El **warning KGP** no se pudo
> eliminar aún (bloqueado por `cloud_firestore`, ver «Pendiente»).
> Ficha: [`docs/features/app-check.md`](docs/features/app-check.md).
>
> **Hecho en Fase 8:** feature `features/profile/` (perfil + estadísticas de juego). Pantalla `/perfil`
> con cabecera editable (nombre/avatar), código de invitación, tipo de cuenta, "miembro desde", saldo y
> acceso al historial, más una grilla de estadísticas (manos, % victoria, blackjacks, rachas, totales).
> Las stats las acumula **server-side** la Function `playerAction` en `users/{uid}.stats` (función pura
> `acumularStats` en `functions/src/blackjack.ts`, espejo de `profile/domain/estadisticas.dart`); el
> cliente solo las lee (`firestore.rules` protege `stats`). **Solo el multijugador** alimenta las stats.
> Accesos desde `BarraEstado` y `PanelAjustes`. Ficha: [`docs/features/perfil.md`](docs/features/perfil.md).
>
> **Hecho en Fase 9:** progresión en `features/profile/` — **XP + niveles** (derivados de la XP, escala
> migrada de `stats.js`: `profile/domain/niveles.dart`) y **logros** desbloqueables
> (`profile/domain/logros.dart`). La Function `playerAction` otorga XP (`xpDeRonda`) y evalúa logros
> (`functions/src/logros.ts` → `arrayUnion` en `users/{uid}.logros`) server-side; el cliente solo lee
> (`firestore.rules` protege `stats`+`logros`). UI: barra de nivel + galería de logros en `perfil_page`,
> y **toast** al desbloquear vía `ref.listen(logrosProvider)` global en `app.dart` (con
> `scaffoldMessengerKey`). Ficha: [`docs/features/progresion.md`](docs/features/progresion.md).
>
> **Hecho en Fase 10a:** leaderboards semanales en `features/leaderboards/`. Ranking por semana ISO
> (`leaderboards/{periodo}/entries/{uid}`) con 3 métricas (ganancia neta, manos ganadas, mejor racha),
> top global + top de amigos + posición propia. `playerAction` agrega la entrada de la semana en su
> transacción; scheduled function `purgarLeaderboards` (`onSchedule`) purga periodos > 8 semanas. Util de
> semana ISO `core/utils/semana.dart` ↔ `functions/src/semana.ts`. `firestore.rules` protege
> `leaderboards`. Ficha: [`docs/features/leaderboards.md`](docs/features/leaderboards.md).
>
> **Hecho en Fase 10b:** bono diario con **racha** de días consecutivos (`features/wallet/`). La Function
> `claimDailyBonus` (`functions/src/dailyBonus.ts`) acredita una recompensa creciente (día 1 = 500, +100
> hasta el tope día 7 = 1100), valida un reclamo por día calendario UTC y guarda `dailyStreak` +
> `lastDailyBonusDay` (protegidos en `firestore.rules`). UI: `BonoDiarioPage` (`/bono`) con la racha y el
> botón de reclamo; lógica pura espejo en `wallet/domain/bono_diario.dart`. Ficha:
> [`docs/features/bono-diario.md`](docs/features/bono-diario.md).
>
> **Hecho en Fase 10c:** misiones diarias/semanales (`features/misiones/`). Progreso server-side por
> periodo en `users/{uid}/progreso/{día|semana}` (lo acumula `playerAction`); recompensa reclamable e
> idempotente vía `claimMission` (`functions/src/misiones.ts`). Catálogo espejo TS↔Dart
> (`misiones/domain/mision.dart`), `MisionesPage` (`/misiones`) con progreso y reclamo, tipo de
> transacción `mission_reward`. Ficha: [`docs/features/misiones.md`](docs/features/misiones.md).
> Con esto la **Fase 10 queda completa** (10a leaderboards · 10b bono con racha · 10c misiones).
>
> **Siguiente — Fases 11–14:** hoja de ruta en [`docs/plans/`](docs/plans/)
> (monetización/PWA/push, Remote Config + A/B, comunicación, distribución…).
