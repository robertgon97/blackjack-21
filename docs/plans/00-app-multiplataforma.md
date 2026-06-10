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
| 3.5 | Conversión de cuenta anónima → permanente (account linking + bono) | ✅ |
| 4 | Social: amigos y transferencias | ✅ |
| 5 | Salas multijugador en tiempo real | ✅ |
| 6 | Observabilidad base: Crashlytics + Analytics (full) | ⬜ |
| 7 | Endurecimiento del backend: App Check | ⬜ |
| 8 | Perfil + estadísticas de juego (server-side) | ⬜ |
| 9 | Progresión: niveles/XP + logros (migra `stats.js`) | ⬜ |
| 10 | Leaderboards semanales + top de amigos + bono diario + misiones | ⬜ |
| 11 | Monetización y pulido (anuncios, PWA, push) | ⬜ |
| 12 | Configuración remota y experimentos: Remote Config + A/B Testing | ⬜ |
| 13 | Comunicación en sala (chat + voz + cámara) | ⬜ |
| 14 | Distribución y calidad de builds: App Distribution + Test Lab | ⬜ |

> Leyenda: ⬜ pendiente · 🚧 en curso · ✅ hecho. Actualizar al avanzar.

### Criterio del orden (6 → 14)

Reordenadas por **valor/esfuerzo y dependencias**, no por el tema en que se diseñaron:

1. **Fundación (6–7):** primero *medir y capturar errores* (Observabilidad) y *proteger el dinero
   virtual* ya en producción (App Check). Barato y habilita todo lo demás.
2. **Bucle de retención (8–10):** Perfil → Progresión → Leaderboards. Es el "sabor" de app de juego y
   el hueco detectado; comparte instrumentación con Analytics (Fase 6).
3. **Crecimiento (11–12):** Monetización + push (ya hay logros/leaderboards que notificar y base de
   usuarios) y luego Remote Config + A/B (A/B necesita tráfico para valer).
4. **Features caras y proceso (13–14):** Comunicación voz/cámara (LiveKit, lo más complejo) y, al
   final, Distribución + Test Lab (endurecer el proceso de builds).

Detalle: [`01-firebase-observabilidad-y-crecimiento.md`](01-firebase-observabilidad-y-crecimiento.md)
(fases 6, 7, 12, 14) y
[`02-perfil-progresion-y-leaderboards.md`](02-perfil-progresion-y-leaderboards.md) (fases 8–10).
**Windows queda fuera** de los servicios Firebase (fases 6, 7, 12).

> **Nota:** la posición más debatible es **Comunicación (13)**: si se quiere que el multijugador recién
> hecho "brille" antes, su **chat de texto** (barato) puede adelantarse separándolo de la voz/cámara
> (lo caro). Se decide al llegar.

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

- `ci.yml` (push+PR): dos jobs:
  - **Analyze & Test:** `flutter pub get` → `dart format --set-exit-if-changed .` → `flutter analyze
    --fatal-infos` → `flutter test` (con coverage).
  - **Lint & Build Functions:** `npm ci` → `npm run lint` (ESLint) → `npm run build` (tsc) en `functions/`.
- `deploy-web.yml` (push a main): `flutter build web --release --base-href /blackjack-21/` →
  GitHub Pages.
- `deploy-firebase.yml` (push a main): **tres jobs en paralelo**, autenticados con
  `FIREBASE_SERVICE_ACCOUNT` (secret en GitHub Actions, **nunca en el repo**):
  - Firestore: `firebase deploy --only firestore:rules,firestore:indexes`
  - **Functions:** `npm ci` (Node 22) → `firebase deploy --only functions`
  - Hosting: `flutter build web --release` → `firebase deploy --only hosting`
- `build-artifacts.yml` (push a main + manual): APK **debug** (Android) y build **Windows** release,
  publicados como artefactos (30 días).
- `release.yml` (tag `v*`): **APK + AAB firmados** (Android) + iOS sin firmar (macOS). La firma usa el
  keystore desde `key.properties` (generado de los GitHub Secrets del keystore), y el **versionado es
  dinámico**: `versionName` sale del tag (`v0.1.0` → `0.1.0`) y `versionCode` del número de ejecución
  del workflow (entero creciente, requisito de Play Store). Sube los artefactos a una GitHub Release.

> iOS sin firmar valida que compila. Instalar en iPhone real / publicar en App Store requiere cuenta
> Apple Developer (US$99/año) + firma → paso manual futuro.

## Estado de herramientas

- ✅ Node, git, Firebase CLI instalados.
- ✅ Flutter / Dart instalados.
- ✅ Proyecto Firebase `blackjack-21-app` configurado (Firestore `southamerica-east1`, Auth, Hosting).
- ✅ `firebase_options.dart` generado con FlutterFire CLI (web, Android, iOS, Windows).
- ✅ `FIREBASE_SERVICE_ACCOUNT` cargado como secret en GitHub Actions → deploy automático sin intervención manual.
- ✅ **Plan Blaze** activo (Cloud Functions desplegándose en producción desde la Fase 4).
- ✅ Proveedores Auth habilitados en consola Firebase: Email/Password, Google, Anónimo.
- ✅ **Firma Android** lista: keystore + 4 GitHub Secrets (`ANDROID_KEYSTORE_*`); `release.yml` firma APK/AAB.
- ✅ **Google Sign-In Android**: huellas SHA-1/SHA-256 registradas en Firebase (`google-services.json` con OAuth client de tipo 1).
