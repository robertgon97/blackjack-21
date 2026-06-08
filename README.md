# Blackjack 21

App multiplataforma de Blackjack (21) con multijugador en tiempo real, desarrollada en **Flutter**.
Disponible en **Android**, **Web**, **Windows** e **iOS**.

## Estado del proyecto

| Fase | Descripción | Estado |
|------|-------------|--------|
| 0 | Andamiaje, docs y migración del repo | ✅ Completa |
| 1 | Lógica pura (domain) + 32 tests | ✅ Completa |
| 2 | Juego solo en Flutter (UI) | 🔲 Pendiente |
| 3 | Auth + perfil + saldo persistente | 🔲 Pendiente |
| 4 | Social: amigos y transferencias | 🔲 Pendiente |
| 5 | Salas multijugador en tiempo real | 🔲 Pendiente |
| 6 | Comunicación en sala (chat + voz + cámara) | 🔲 Pendiente |
| 7 | Monetización y pulido | 🔲 Pendiente |

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
  main.dart · app.dart          ← entrada de la app
  core/                         ← tema, router, widgets compartidos
  features/
    game/domain/                ← lógica pura del blackjack (sin Firebase/UI)
    auth/ · wallet/ · friends/
    rooms/ · comms/ · profile/
test/                           ← tests de domain (32 asserts)
functions/                      ← Cloud Functions (TypeScript)
docs/                           ← reglas de negocio y arquitectura
legacy-web/                     ← juego JS original archivado
```

Consulta [`docs/README.md`](docs/README.md) para la documentación completa.

## CI/CD

| Workflow | Disparador | Qué hace |
|----------|-----------|----------|
| `ci.yml` | push / PR a main | `dart format` + `flutter analyze` + `flutter test` |
| `deploy-web.yml` | push a main | `flutter build web` → GitHub Pages |
| `release.yml` | tag `v*` | APK Android + build iOS sin firma → GitHub Release |

> **Nota GitHub Pages:** en Settings → Pages → Source debe estar en **"GitHub Actions"**.

## Juego original (JS vanilla)

La primera versión del proyecto (HTML + JS puro + Tailwind CSS) está archivada en
[`legacy-web/`](legacy-web/). Consulta su README para correrla.
