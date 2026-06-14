---
fase: 7
estado: ✅ hecho (modo monitor; enforcement pendiente en consola)
---

# App Check — endurecimiento del backend

## Qué hace

Activa **Firebase App Check** para atestiguar que las llamadas a Firebase (Firestore, Functions)
provienen de la **app legítima** y no de un cliente falsificado. Es relevante porque la app maneja
**dinero virtual** y Cloud Functions sensibles (`startRound`, `playerAction`, `transferCredits`).

## Arquitectura

Sigue el mismo patrón de abstracción por plataforma que la telemetría (Fase 6):

```
core/app_check/
├── domain/i_servicio_app_check.dart        ← interfaz (contrato: activar())
├── data/firebase_app_check_service.dart     ← impl. real (Android/iOS/Web)
├── data/noop_app_check_service.dart         ← impl. vacía (Windows/Linux/tests)
└── app_check_provider.dart                  ← factory por plataforma + provider Riverpod
```

`crearServicioAppCheck()` elige la implementación según la plataforma:

| Plataforma | Proveedor (release) | Proveedor (debug) |
|------------|---------------------|-------------------|
| Android | Play Integrity | Debug provider |
| iOS | App Attest | Debug provider |
| Web | reCAPTCHA v3 | reCAPTCHA v3 |
| Windows / Linux | no-op | no-op |

## Activación

En `lib/main.dart`, **después** de `Firebase.initializeApp()` y **sin bloquear** `runApp()`:

```dart
unawaited(crearServicioAppCheck().activar());
```

> ⚠️ **No usar `await`**: la atestación (p. ej. Play Integrity) puede colgarse y bloquear el primer
> frame → pantalla negra. Va *fire-and-forget*; `activar()` captura sus propios errores. Ver
> [`../errores-y-correcciones.md`](../errores-y-correcciones.md) (2026-06-14).

## Enforcement gradual (modo monitor)

Esta fase **solo activa el envío de tokens desde el cliente**. El *enforcement* (rechazar llamadas sin
token válido) **no** se activa en el código todavía: ni `firestore.rules` ni las Cloud Functions
(`enforceAppCheck`) se tocaron. El enforcement se habilita **desde la consola** de Firebase tras medir
en la pestaña App Check que el tráfico legítimo llega verificado, para no romper a usuarios reales.

## Configuración manual requerida (Firebase Console / Google Cloud)

Estas acciones las realiza el responsable del proyecto (no son código):

1. **App Check → Apps → Android**: registrar **Play Integrity** (y habilitar la *Play Integrity API* en
   Google Cloud).
2. **Debug token (desarrollo):** correr la app en debug, copiar el token que imprime el log
   (`DebugAppCheckProvider`) y registrarlo en **App Check → Apps → Manage debug tokens**.
3. **Web:** generar una **site key de reCAPTCHA v3** y pasarla al compilar:
   `flutter build web --dart-define=RECAPTCHA_SITE_KEY=<key>`.
4. **iOS:** registrar App Attest (no urgente; aún no hay firma iOS).
5. Cuando las métricas de monitor estén limpias: activar **enforcement** en Firestore y en las
   Callable Functions desde la consola.

## Dependencias externas

- `firebase_app_check` (tras la interfaz `IServicioAppCheck` en `domain`).

## Casos borde

- **Windows/Linux** → `NoopAppCheckService`: no hace nada (App Check no soporta esas plataformas).
- **Activación falla o se cuelga** → la app arranca igual (fire-and-forget + `try-catch`).
- **APK sideloaded (no Play Store)** → Play Integrity puede no atestiguar; en modo monitor no bloquea.

## Cómo probarlo

- **Arranque:** instalar el APK de release y confirmar que la app llega a la pantalla de login (no
  pantalla negra) y `logcat` muestra `FirebaseApp initialization successful` sin excepciones.
- **Verificado (2026-06-14, Galaxy A15):** modo demo (login anónimo) entra al juego con saldo $1000.
- **Consola:** con el debug token registrado, comprobar en App Check que llegan peticiones verificadas.
