# Plan maestro: Blackjack 21 → App Multiplataforma (Flutter + Firebase)

> Documento vivo. Refleja el plan aprobado para convertir el juego web en una app multiplataforma.
> Las reglas de negocio detalladas viven en [`../reglas-negocio/`](../reglas-negocio/) y la
> arquitectura en [`../arquitectura/`](../arquitectura/).

## Contexto

El proyecto nació como un Blackjack solo (jugador vs sistema) en HTML + JS vanilla + Tailwind,
desplegado en GitHub Pages (conservado en [`../../legacy-web/`](../../legacy-web/)). La lógica del
juego estaba bien encapsulada en funciones puras, lo que facilita migrarla.

**Objetivo:** una **app multiplataforma** (Android APK, Web, Windows, iOS) con un solo codebase en
**Flutter**, respaldada por **Firebase**, con: login, créditos, amigos, invitaciones por enlace,
transferencias entre usuarios, saldo persistente, historial de movimientos, **partidas multijugador en
tiempo real** (el sistema es el crupier) y **comunicación en la sala** (chat + emojis, voz y cámara
opcional para ver reacciones).

## Decisiones confirmadas

- **Framework:** Flutter (Dart) — un solo código para Android + Web + Windows + iOS.
- **Backend:** Firebase Blaze (Auth + Firestore + Cloud Functions + Hosting/Messaging).
- **Turnos multijugador:** simultáneos, con temporizador de 45 s (configurable por el host).
- **Repo:** el mismo; el juego JS original se archiva en `legacy-web/`.
- **CI/CD:** Web (GitHub Pages + Firebase Hosting), Android APK e iOS (build sin firmar), deploy automático de reglas e índices de Firestore.
- **Comunicación en sala:** chat de texto + emojis, voz y cámara opcional (apagada por defecto).
- **Voz/video:** LiveKit (open-source, nube gratis, self-hosteable), **detrás de una abstracción**
  para poder cambiar de proveedor sin tocar la UI.

## Flujo de trabajo con el asistente (reglas de colaboración)

- **Aprobación antes de commitear:** el asistente prepara los cambios y los explica, pero
  **no hace `git push` sin confirmación explícita del usuario**. Cada commit se muestra antes
  de ejecutarse; el usuario dice "sí" o pide ajustes.
- **Registro de errores:** si el asistente comete un error (código incorrecto, suposición equivocada,
  regresión), lo documenta inmediatamente en [`../errores-y-correcciones.md`](../errores-y-correcciones.md)
  con: qué falló, por qué, y qué se corrigió. Ese archivo es el historial de aprendizaje del proyecto.

## Principios de calidad (no negociables)

- **Arquitectura limpia por capas:** `domain` (lógica pura) → `data` (repositorios) → `presentation`
  (UI + estado). La lógica del juego nunca conoce Firebase ni widgets.
- **Feature-first:** cada funcionalidad es una carpeta autónoma.
- **Abstracción de proveedores externos** (voz/video, anuncios, push) por *interface* en `domain`.
- **Módulos pequeños, una sola responsabilidad.** Sin duplicar lógica.
- **Código documentado** con doc-comments `///` en español.
- **Inmutabilidad:** modelos `freezed`.
- **Testeable:** la capa `domain` cubierta por `flutter test`.
- **Documentación viva en `docs/`** y README + CLAUDE.md actualizados al cerrar cada fase.

## Stack

| Capa | Tecnología |
|------|-----------|
| UI / App | Flutter 3.x (Dart) |
| Estado | Riverpod |
| Navegación | go_router (deep links `/join/CODE`) |
| Modelos | freezed + json_serializable |
| Auth | firebase_auth + google_sign_in (email, Google, anónimo) |
| BD tiempo real | cloud_firestore (`snapshots()`) |
| Lógica servidor | Cloud Functions (TypeScript) |
| Voz/Video | LiveKit (`livekit_client`) tras abstracción |
| Chat texto/emoji | cloud_firestore |
| Hosting web | Firebase Hosting + GitHub Pages (ambos por Actions) |
| Push | firebase_messaging |
| Anuncios | google_mobile_ads / AdSense |

## Fases

| Fase | Contenido | Estado |
|------|-----------|:------:|
| 0 | Andamiaje, docs y migración del repo (legacy-web/, flutter create, workflows) | ✅ |
| 1 | Lógica pura del juego (domain) + tests migrados | ✅ |
| 2 | Juego solo en Flutter (UI, 4 temas) | ✅ |
| 3 | Auth + perfil + saldo persistente | ✅ |
| 3.5 | Conversión de cuenta anónima → permanente (account linking + bono) | ⬜ |
| 4 | Social: amigos y transferencias | ✅ |
| 5 | Salas multijugador en tiempo real | ⬜ |
| 6 | Comunicación en sala (chat + voz + cámara) | ⬜ |
| 7 | Monetización y pulido (anuncios, leaderboard, PWA, push) | ⬜ |

> Leyenda: ⬜ pendiente · 🚧 en curso · ✅ hecho. Actualizar al avanzar.

**Cierre de cada fase:** `dart format` + `flutter analyze` + `flutter test` en verde, ficha en
`docs/features/` y reglas en `docs/reglas-negocio/` creadas/actualizadas, README + CLAUDE.md al día, y
un commit por fase.

## Fase 3.5 — Conversión de cuenta anónima → permanente

**Problema detectado:** quien entra en modo demo anónimo queda "atrapado": el `redirect` del router
nunca lo devuelve a `/login`, así que **no hay forma de registrarse** sin perder el progreso (una cuenta
anónima de Firebase no se recupera tras cerrar sesión).

**Solución:** vinculación de credenciales (account linking) de Firebase Auth — convierte la cuenta
anónima en permanente (email o Google) **conservando el mismo `uid`** (saldo, `inviteCode`, amigos e
historial intactos), con un **bono de +500 créditos** la primera vez (idempotente, vía Cloud Function).
Incluye incitación descartable a registrarse y advertencia al cerrar sesión siendo anónimo.

Es una mejora autocontenida de la Fase 3 (auth); puede hacerse antes o en paralelo a la Fase 5. Diseño
completo, casos de uso y casos borde en [`../features/conversion-cuenta.md`](../features/conversion-cuenta.md).

## Migración de la lógica del juego (JS → Dart)

Las funciones puras se traducen línea por línea (sin DOM ni efectos); comportamiento idéntico,
verificado por los tests migrados.

| Origen (JS) | Destino (Dart) |
|-------------|----------------|
| `cartas.js` (puntos, infoMano, split, probabilidades, Hi-Lo) | `game/domain/cartas.dart` |
| `estrategia.js` | `game/domain/estrategia.dart` |
| `juego.js` (resolverMano, debePedirCrupier, opcionesActuales) | `game/domain/reglas.dart` |
| `stats.js` (NIVELES, LOGROS, nivelActual) | `profile/domain/` |
| `config.js` | `ConfigJuego` (freezed) |
| `ui.js`, `main.js`, `audio.js` | No se migran (UI en widgets; sonidos en pulido) |
| `tests/test.js` | `test/*.dart` |

## CI/CD

- `ci.yml` (push+PR): `flutter pub get` → `dart format --set-exit-if-changed .` → `flutter analyze` →
  `flutter test`.
- `deploy-web.yml` (push a main): `flutter build web --release --base-href /blackjack-21/` →
  GitHub Pages.
- `deploy-firebase.yml` (push a main): dos jobs en paralelo:
  - Firestore: `firebase deploy --only firestore:rules,firestore:indexes`
  - Hosting: `flutter build web --release` → `firebase deploy --only hosting`
  - Autenticado con `FIREBASE_SERVICE_ACCOUNT` (secret en GitHub Actions, **nunca en el repo**).
  - Al agregar Functions (Fase 4+): solo extender `--only` con `functions`.
- `release.yml` (tag `v*`): APK (ubuntu) + iOS sin firmar (macos).

> iOS sin firmar valida que compila. Instalar en iPhone real / publicar en App Store requiere cuenta
> Apple Developer (US$99/año) + firma → paso manual futuro.

## Estado de herramientas

- ✅ Node, git, Firebase CLI instalados.
- ✅ Flutter / Dart instalados.
- ✅ Proyecto Firebase `blackjack-21-app` configurado (Firestore `southamerica-east1`, Auth, Hosting).
- ✅ `firebase_options.dart` generado con FlutterFire CLI (web, Android, iOS, Windows).
- ✅ `FIREBASE_SERVICE_ACCOUNT` cargado como secret en GitHub Actions → deploy automático sin intervención manual.
- ⏳ **Plan Blaze** en Firebase: habilitar si aún no está (necesario para Cloud Functions en Fase 4+).
- ⏳ Habilitar proveedores Auth en consola Firebase: Email/Password, Google, Anónimo.
