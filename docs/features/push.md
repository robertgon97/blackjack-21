# Feature: Notificaciones push (FCM)

> Sub-PR **11b** de la Fase 11 (monetización y pulido). Otras piezas: 11a PWA (hecho), 11c anuncios.

## Propósito

Retención: avisar al jugador fuera de la app de eventos relevantes. En esta fase, una notificación push
cuando **desbloquea un logro** (server-side, anti-trampa). La infraestructura queda lista para más
disparadores (subir de nivel, racha por expirar) en iteraciones futuras.

## Arquitectura

Mismo patrón que telemetría/App Check: interfaz en `core/push/domain/i_servicio_push.dart`, implementación
Firebase (`data/firebase_push_service.dart`) y **no-op** (`data/noop_push_service.dart`) para
Windows/Linux, elegida en `push_provider.dart` por plataforma.

- **Cliente:** `inicializar(uid)` (idempotente) pide permiso, obtiene el token FCM y lo guarda en
  `users/{uid}.fcmTokens` (`arrayUnion`; un usuario puede tener varios dispositivos). Se llama desde
  `app.dart` cuando el perfil emite (tras login).
- **Servidor:** `playerAction`, tras resolver la ronda y evaluar logros, envía un push a los `fcmTokens`
  del usuario por cada logro nuevo (`getMessaging().sendEachForMulticast`), **fuera de la transacción**
  (un fallo de envío no afecta la ronda ya persistida). El texto usa `nombreLogro` (`functions/src/logros.ts`).

## Plataformas

| Plataforma | Estado |
|---|---|
| Android | ✅ funciona con `google-services.json` (ya presente) |
| Web | ✅ requiere la **VAPID key** (en `firebase_push_service.dart`) + `web/firebase-messaging-sw.js` (incluido) |
| iOS | ⏳ requiere cuenta Apple Developer + APNs (diferido, como la firma iOS) |
| Windows/Linux | no-op |

### VAPID key (Web)

Clave pública (no secreta) para Web Push. Se genera en la consola de Firebase → **Cloud Messaging →
Certificados push web → Generar par de claves**, y se pega en `_vapidKeyWeb`
(`lib/core/push/data/firebase_push_service.dart`).

## Modelo de datos tocado

`users/{uid}.fcmTokens` (`array<string>`): tokens FCM de los dispositivos del usuario. Lo escribe el
**propio dueño** (no es campo protegido); las Functions lo leen para enviar push.

## Casos borde

- **Permiso denegado** → no se obtiene token; no se envía nada (sin error visible).
- **Sin tokens** (usuario nunca concedió permiso) → `playerAction` no intenta enviar.
- **Token inválido/expirado** → `sendEachForMulticast` falla por ese token; se ignora (mejora futura:
  limpiar tokens muertos del array).
- **Windows** → no-op; nunca pide permiso ni token.

## Cómo probarlo

- **Android:** instalar, conceder el permiso de notificaciones, jugar hasta desbloquear un logro (p. ej.
  ganar la primera mano en multijugador) con la app en segundo plano → llega la notificación.
- **Web:** tras pegar la VAPID key y desplegar, conceder el permiso del navegador; el `firebase-messaging-sw.js`
  recibe el push en segundo plano.

## Pendiente de la Fase 11

- **11c** anuncios (AdMob) — *rewarded* "ver anuncio → créditos", con IDs de prueba hasta tener cuenta.
- Más disparadores de push (nivel, racha por expirar) e *limpieza de tokens* muertos.
