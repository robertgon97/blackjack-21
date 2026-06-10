# Blackjack 21

App multiplataforma de Blackjack (21) con multijugador en tiempo real, desarrollada en **Flutter**.
Disponible en **Android**, **Web**, **Windows** e **iOS**.

## Estado del proyecto

| Fase | Descripción | Estado |
|------|-------------|--------|
| 0 | Andamiaje, docs y migración del repo | ✅ Completa |
| 1 | Lógica pura (domain) + tests | ✅ Completa |
| 2 | Juego solo en Flutter (UI, 4 temas) | ✅ Completa |
| 3 | Auth + perfil + saldo persistente | ✅ Completa |
| 3.5 | Conversión de cuenta anónima → permanente | ✅ Completa |
| 4 | Social: amigos y transferencias | ✅ Completa |
| 5 | Salas multijugador en tiempo real | ✅ Completa |
| 6 | Observabilidad: Crashlytics + Analytics | ✅ Completa |
| 7 | Endurecimiento del backend: App Check | 🔲 Pendiente |
| 8 | Perfil + estadísticas de juego | 🔲 Pendiente |
| 9 | Progresión: niveles/XP + logros | 🔲 Pendiente |
| 10 | Leaderboards + bono diario + misiones | 🔲 Pendiente |
| 11 | Monetización y pulido (anuncios, PWA, push) | 🔲 Pendiente |
| 12 | Remote Config + A/B Testing | 🔲 Pendiente |
| 13 | Comunicación en sala (chat + voz + cámara) | 🔲 Pendiente |
| 14 | Distribución: App Distribution + Test Lab | 🔲 Pendiente |

> Roadmap detallado de las fases 6–14 en [`docs/plans/`](docs/plans/).

## Cómo correr (desarrollo)

```bash
# 1) Instalar dependencias
flutter pub get

# 2) Correr (elige plataforma)
flutter run -d chrome       # web
flutter run -d windows      # escritorio Windows
flutter run -d <device-id>  # Android (cable o emulador)

# 3) Tests y análisis
flutter test
flutter analyze
```

## Stack

- **Flutter 3.x + Dart** — un solo código para Android, Web, Windows e iOS
- **Firebase** — Auth, Firestore, Cloud Functions
- **Riverpod** — gestión de estado
- **go_router** — navegación + deep links (`/join/CODIGO`)
- **LiveKit** — voz y cámara en sala (detrás de una interfaz intercambiable)

## Estructura del repo

```
lib/
  main.dart · app.dart          ← entrada de la app (ProviderScope + tema)
  core/theme/                   ← 4 temas (ColorScheme + ColoresTapete)
  features/
    game/domain/                ← lógica pura del blackjack (sin Firebase/UI)
    game/presentation/          ← UI del juego solo (controlador Riverpod + widgets)
    auth/ · wallet/ · friends/
    rooms/ · comms/ · profile/
test/                           ← tests de domain (42 tests)
functions/                      ← Cloud Functions (TypeScript)
docs/                           ← reglas de negocio y arquitectura
legacy-web/                     ← juego JS original archivado
```

Consulta [`docs/README.md`](docs/README.md) para la documentación completa.

## CI/CD

| Workflow | Disparador | Qué hace |
|----------|-----------|----------|
| `ci.yml` | push / PR a main | Analyze & Test (format + analyze + test) y Lint & Build de Functions |
| `deploy-web.yml` | push a main | `flutter build web` → GitHub Pages |
| `deploy-firebase.yml` | push a main | Firestore (reglas + índices) + Functions + Hosting |
| `build-artifacts.yml` | push a main + manual | APK debug (Android) + build Windows |
| `release.yml` | tag `v*` | APK + AAB **firmados** + iOS sin firma → GitHub Release (versión desde el tag) |

> **Nota GitHub Pages:** en Settings → Pages → Source debe estar en **"GitHub Actions"**.

## Juego original (JS vanilla)

La primera versión del proyecto (HTML + JS puro + Tailwind CSS) está archivada en
[`legacy-web/`](legacy-web/). Consulta su README para correrla.
