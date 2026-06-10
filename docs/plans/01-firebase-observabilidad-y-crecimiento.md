# Plan: Observabilidad, robustez y crecimiento con Firebase

> Documento vivo. Continúa el [plan maestro](00-app-multiplataforma.md) con las fases que sacan
> provecho del resto de la plataforma Firebase. Cada fase es **pequeña y autónoma** (se puede
> mergear sola, con su CI en verde y su ficha en [`../features/`](../features/)).

## Contexto

El backend ya usa **Auth + Firestore + Cloud Functions + Hosting**. Estas fases añaden la capa de
*observabilidad* (saber qué pasa y por qué falla), *endurecimiento* (proteger el backend del abuso) y
*crecimiento* (configurar y experimentar sin re-publicar). No introducen features de juego nuevas;
hacen que lo existente sea medible, robusto y operable en producción.

## Decisión transversal #1 — Plataformas (Windows queda fuera)

La matriz oficial de FlutterFire deja claro que **estos servicios no soportan Windows** (y Crashlytics
y Performance tampoco soportan Web):

| Servicio | Android | iOS | Web | Windows |
|---|:-:|:-:|:-:|:-:|
| App Check | ✅ | ✅ | ✅ | ❌ |
| Crashlytics | ✅ | ✅ | ❌ | ❌ |
| Analytics | ✅ | ✅ | ✅ | ❌ |
| Remote Config | ✅ | ✅ | ✅ | ❌ |
| Cloud Messaging | ✅ | ✅ | ✅ | ❌ |
| Performance | ✅ | ✅ | ❌ | ❌ |

**Regla de oro de implementación:** toda inicialización y todo registro de telemetría se hace **detrás
de una guarda de plataforma** (p. ej. una interfaz `ServicioTelemetria` en `domain` con una impl. real
en móvil/web y una impl. **no-op** en Windows). Así Windows nunca crashea ni "se queja" por un servicio
ausente, y la capa `presentation` llama siempre a la misma interfaz. Esto respeta el principio del
proyecto de **abstraer proveedores externos por interfaz en `domain`**.

## Decisión transversal #2 — Privacidad y consentimiento

Analytics y Crashlytics recogen datos de uso. En web/UE esto exige un **aviso de privacidad** y, idealmente,
un consentimiento que permita desactivar la recolección. Se contempla un toggle "Compartir datos de uso"
en ajustes (por defecto activado donde la ley lo permita; desactivado hasta consentir en la UE).

## Principios (heredados del plan maestro)

- **Sin cruzar capas:** la telemetría se expone como interfaz en `domain`; `data` la implementa; la
  lógica de juego (`game/domain`) **no** conoce Firebase.
- **Inicialización condicional por plataforma** (móvil/web/Windows), nunca con `if` dispersos en la UI.
- **CI en verde** (`dart format` + `analyze --fatal-infos` + `flutter test`) y **ficha en `docs/features/`**
  al cerrar cada fase.
- **Nada de Dynamic Links** (discontinuado por Google): los deep links propios (`/join/CODE`) ya cubren ese caso.

---

## Fase 8 — Observabilidad base (Crashlytics + Analytics)

**Objetivo:** ver crashes reales y entender cómo se usa la app. Es la fase fundacional: las demás se
apoyan en Analytics.

### Crashlytics (cobertura completa)
- Captura de **errores fatales** y **no fatales** (errores atrapados que igual queremos registrar).
- Enganche global: `FlutterError.onError` y `PlatformDispatcher.instance.onError` → Crashlytics.
- **Custom keys** por sesión: `uid`, `sala_actual`, `fase_juego`, `plataforma`, `tema`.
- **Breadcrumbs** (logs) en acciones clave para reconstruir el camino al crash.
- Registro de fallos de llamadas a Cloud Functions (`startRound`, `playerAction`, `transferCredits`).

### Analytics (instrumentación completa, "full")
- **Pantallas**: registro automático de navegación (observer de `go_router`).
- **Juego**: `ronda_iniciada`, `mano_resuelta` (con resultado), `accion_jugador` (pedir/plantarse/doblar/dividir/rendirse), `blackjack`.
- **Economía**: `apuesta_realizada`, `transferencia`, `bono_conversion`, `saldo_agotado`.
- **Social/salas**: `amigo_agregado`, `sala_creada`, `sala_unida`, `invitacion_usada`.
- **Embudos**: registro → primera partida; anónimo → conversión a cuenta permanente.
- **User properties**: nivel, rango de saldo (bucket), tema preferido, tipo de cuenta (anónima/permanente).
- **DebugView** para validar en desarrollo; (opcional) export a **BigQuery** para análisis libre.

**Plataformas:** Android, iOS (Crashlytics + Analytics) · Web (solo Analytics) · Windows: no-op.
**Cierre:** eventos visibles en DebugView, un crash de prueba aparece en la consola, ficha
`docs/features/observabilidad.md`, toggle de privacidad en ajustes.
**Dependencias:** ninguna (puede ir tras la Fase 5).

---

## Fase 9 — Endurecimiento del backend (App Check)

**Objetivo:** garantizar que solo la app legítima llama a Firestore, Functions y Storage. Relevante
porque hay **dinero virtual** y Functions sensibles.

- Proveedores: **Play Integrity** (Android), **App Attest/DeviceCheck** (iOS), **reCAPTCHA** (Web).
- **Enforcement gradual:** primero en modo monitor (sin bloquear) para medir tráfico legítimo; luego
  enforcement en Firestore y en las Callable Functions.
- **Windows exento:** al no haber proveedor, las llamadas desde Windows no llevan token; se decide si
  Windows se deja como cliente "no verificado" (sin enforcement) o se retira como target de producción.
- Debug tokens para desarrollo y para el CI.

**Plataformas:** Android, iOS, Web · Windows: sin App Check (decisión de alcance).
**Cierre:** App Check en monitor sin falsos positivos durante X días, luego enforcement; ficha
`docs/features/app-check.md`.
**Dependencias:** conviene tener Analytics (Fase 8) para medir el impacto del enforcement.

---

## Fase 10 — Configuración remota y experimentos (Remote Config + A/B Testing)

**Objetivo:** ajustar parámetros y probar variantes **sin publicar una versión nueva**.

### Remote Config
- Parámetros del juego con valores por defecto locales y override remoto: `apuesta_min`, `apuesta_max`,
  `timer_seg`, `bono_conversion`, `num_barajas`.
- **Feature flags** para activar/desactivar features en caliente (p. ej. comunicación de voz, salas).
- Carga segura: valores por defecto empaquetados → la app nunca depende de la red para arrancar.

### A/B Testing (sobre Remote Config + Analytics)
- Experimentos como: monto del bono de conversión, duración del timer, copy de la incitación a registrarse.
- Métrica objetivo definida por experimento (p. ej. tasa de conversión anónimo→permanente).

**Plataformas:** Android, iOS, Web · Windows: usa solo los valores por defecto locales.
**Cierre:** un parámetro real (p. ej. `timer_seg`) controlado desde la consola; un experimento A/B
configurado; ficha `docs/features/remote-config.md`.
**Dependencias:** Analytics (Fase 8) es requisito de A/B Testing.

---

## Fase 11 — Distribución y calidad de builds (App Distribution + Test Lab)

**Objetivo:** repartir betas a testers y validar en dispositivos reales.

### App Distribution
- Subida automática del APK/AAB firmado (y del iOS cuando haya firma) a grupos de testers desde el CI,
  enganchado al workflow `release.yml` ya existente (extiende, no reemplaza).
- Reemplaza el envío manual de APKs.

### Test Lab
- Requiere **antes** escribir `integration_test` (hoy solo hay tests de dominio). Smoke test del flujo
  crítico: login → crear sala → jugar una ronda.
- Ejecución del smoke test en una matriz pequeña de dispositivos en el CI.

**Plataformas:** Android, iOS.
**Cierre:** una beta distribuida a un grupo de testers; un `integration_test` corriendo en Test Lab; ficha
`docs/features/distribucion-y-pruebas.md`.
**Dependencias:** la firma de release ya está lista; Test Lab depende de tener `integration_test`.

---

## Diferido / opcional (sin fase asignada aún)

- **Performance Monitoring** (Android/iOS): latencia de red y arranque, cuando crezca la base de usuarios.
- **Cloud Storage**: solo si se quieren avatares con foto (hoy son emojis).
- **Vertex AI in Firebase / Genkit**: "coach" de estrategia o moderación de chat con IA (exploratorio).

> **Cloud Messaging (push)** ya está contemplado en la **Fase 7** del plan maestro; no se duplica aquí.

## Resumen de fases

| Fase | Contenido | Plataformas | Depende de |
|------|-----------|-------------|------------|
| 8 | Observabilidad base: Crashlytics + Analytics (full) | And/iOS (+Web Analytics) | — |
| 9 | App Check (endurecimiento del backend) | And/iOS/Web | Fase 8 (recomendado) |
| 10 | Remote Config + A/B Testing | And/iOS/Web | Fase 8 (A/B) |
| 11 | App Distribution + Test Lab | And/iOS | firma release (lista); `integration_test` |

## Costos (plan Blaze, ya activo)

- **Gratis** dentro de cuotas amplias: Crashlytics, Analytics, App Check (Play Integrity/App Attest),
  Remote Config, A/B Testing, App Distribution, Cloud Messaging, Performance.
- **Posible costo sobre cuota:** reCAPTCHA Enterprise (App Check web) y **Test Lab** (por minuto de
  dispositivo; hay cuota diaria gratis). Se monitorea en la consola de facturación.
