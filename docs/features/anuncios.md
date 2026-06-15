# Feature: Anuncios recompensados (AdMob)

> Sub-PR **11c** de la Fase 11 (monetización y pulido), que **cierra** la fase. Otras piezas: 11a PWA,
> 11b push.

## Propósito

Monetización y recarga: el jugador puede **ver un anuncio recompensado** para recibir créditos. Útil
sobre todo cuando se queda sin saldo en el modo solo.

## Reglas de negocio

- **Solo Android/iOS** (AdMob no soporta Web ni escritorio → ahí el servicio es no-op y el botón se
  oculta). iOS queda preparado pero su Ad Unit se añade con cuenta/firma Apple.
- **IDs de prueba en debug, reales en release** (`mobile_ads_service.dart`): durante el desarrollo nunca
  se cargan los anuncios reales, evitando el baneo de AdMob por "clics inválidos".
- **Recompensa verificada server-side (SSV, anti-trampa):** el cliente **no acredita**. Cuando el usuario
  completa el anuncio, **AdMob llama a la Cloud Function `admobSsv`** con los datos **firmados**; la
  Function verifica la firma ECDSA con la clave pública de Google y, solo si es válida, acredita 200
  créditos al `user_id` (= `uid`, que el cliente pasa como `ServerSideVerificationOptions`). Idempotente
  por `transaction_id` (`users/{uid}/adRewards/{txId}`). El saldo llega al cliente por `saldoProvider`.
  - Así se **certifica criptográficamente** que el anuncio se vio: un cliente modificado no puede
    falsificar la firma de Google.

## Arquitectura

Mismo patrón que telemetría/App Check/push, pero con **conditional imports** porque `google_mobile_ads`
no compila pensado para Web:

```
core/ads/
├── domain/i_servicio_anuncios.dart   ← interfaz (inicializar, disponible, mostrarRecompensado)
├── data/noop_ads_service.dart        ← Web/escritorio (no importa el SDK)
├── data/mobile_ads_service.dart      ← Android/iOS (google_mobile_ads, guard de runtime)
├── ads_factory_stub.dart             ← fábrica Web (noop)
├── ads_factory_io.dart               ← fábrica móvil/escritorio (real)
└── ads_provider.dart                 ← `import stub if (dart.library.io) io`
```

- En **Web** el `import … if (dart.library.io)` elige la fábrica stub → nunca se incluye el SDK.
- El SDK se inicializa en `main.dart` (fire-and-forget, no-op fuera de móvil).
- UI: botón "Ver anuncio (+créditos)" en el modo solo cuando el saldo llega a 0 (`pantalla_juego`); se
  oculta solo si el servicio no está disponible.

## IDs de AdMob

| | Valor |
|---|---|
| App ID (Android, en `AndroidManifest.xml`) | `ca-app-pub-4615188161032989~8584572764` |
| Ad Unit recompensado (release) | `ca-app-pub-4615188161032989/7079919403` |
| Ad Unit recompensado (debug, prueba de Google) | `ca-app-pub-3940256099942544/5224354917` |

Son públicos (no secretos). La cuenta AdMob estaba en revisión/limitada al integrarse: los anuncios
**reales** solo se publican cuando Google aprueba la app y la cuenta; con IDs de prueba la integración
funciona desde ya.

## Cloud Functions relacionadas

- **`admobSsv`** (`functions/src/admobSsv.ts`, HTTP `onRequest`): endpoint que AdMob llama tras un
  anuncio completado. Verifica la firma con las claves públicas de Google
  (`gstatic.com/admob/reward/verifier-keys.json`, cacheadas) y acredita 200 créditos de forma idempotente.

### Configuración pendiente en AdMob (tras desplegar)

La URL del endpoint hay que pegarla en la consola de AdMob para que Google la llame:
1. Desplegar (merge a main) → la Function queda en
   `https://southamerica-east1-blackjack-21-app.cloudfunctions.net/admobSsv`.
2. AdMob → Apps → Blackjack 21 → Unidades de anuncios → "Recarga por anuncio" → **Configuración de
   verificación del servidor (SSV)** → pegar esa URL.
3. (Para probar en debug, el Ad Unit de prueba también dispara SSV con `user_id` de test.)

## Casos borde

- **Web/escritorio** → botón oculto; `mostrarRecompensado(uid)` devuelve `false`.
- **Anuncio no carga / se cierra antes** → AdMob no dispara el SSV → no se acredita nada.
- **Firma inválida / clave desconocida** en `admobSsv` → 4xx, sin acreditar.
- **Reintento del mismo `transaction_id`** → el doc `adRewards/{txId}` ya existe → no se acredita dos veces.
- **Acreditación asíncrona:** el SSV de Google llega unos segundos después; el saldo se refleja por
  `saldoProvider` (la UI avisa "tu recompensa llegará en unos segundos").

## Cómo probarlo

- **Android (debug):** quedarse sin saldo en el juego solo → "Ver anuncio (+créditos)" → ver el anuncio
  de prueba completo → en segundos AdMob llama a `admobSsv` y el saldo sube 200 (transacción `ad_reward`).
  Requiere haber configurado la URL SSV en AdMob (ver arriba).
- **Web:** el botón no aparece (correcto).
