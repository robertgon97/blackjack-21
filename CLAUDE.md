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
- Pendiente (acción manual en consola Firebase):
  - Habilitar plan Blaze (necesario para Cloud Functions)
  - Habilitar proveedores de Auth: Email/Password, Google, Anónimo
  - `flutterfire configure` (genera `lib/firebase_options.dart`)

## Tests

```bash
flutter test                           # corre los 32 tests de domain
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
| `ci.yml` | push/PR a main | format + analyze + test |
| `deploy-web.yml` | push a main | build web → GitHub Pages |
| `release.yml` | tag `v*` | APK Android + build iOS sin firma |

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

## Pendiente (fases futuras)

- `lib/firebase_options.dart` (generado por `flutterfire configure`) — acción manual del usuario
- Cloud Functions en `functions/src/` (TypeScript) — escriben `balance` y `transactions`
- Riverpod providers para las features que faltan (rooms, comms, profile…)
- `freezed` para los modelos (hoy son inmutables con `copyWith` a mano)
- Fichas de `docs/features/` para las features restantes (rooms, comms, profile…)
- **Fase 5 (siguiente):** salas multijugador en tiempo real (ver `docs/reglas-negocio/salas-y-multijugador.md`)

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
