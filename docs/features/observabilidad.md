---
fase: 6
estado: ✅ hecho
---

# Observabilidad base — Crashlytics + Analytics

## Qué hace

Instrumenta la app con Firebase Crashlytics y Firebase Analytics para ver crashes
en producción y entender cómo se usa la app.

## Arquitectura

Sigue el patrón de abstracción de proveedores del proyecto:

```
core/telemetria/
├── domain/i_servicio_telemetria.dart   ← interfaz (contrato)
├── data/firebase_telemetria.dart       ← impl. real (Android/iOS/Web)
├── data/noop_telemetria.dart           ← impl. vacía (Windows / tests)
└── telemetria_provider.dart            ← Riverpod: elige impl. según plataforma
```

El `servicioTelemetriaProvider` devuelve la implementación correcta:

| Plataforma | Crashlytics | Analytics |
|------------|:-----------:|:---------:|
| Android / iOS | ✅ | ✅ |
| Web | ❌ (no soportado) | ✅ |
| Windows | no-op | no-op |

## Cobertura

### Crashlytics
- Hook global en `main.dart`: `FlutterError.onError` + `PlatformDispatcher.instance.onError`.
- Registro de errores no fatales en los `catch` de Cloud Functions (`startRound`,
  `playerAction`, `transferCredits`).
- Custom key `tipo_cuenta` actualizada en cada cambio de perfil (vía `app.dart`).

### Analytics — eventos

| Evento | Cuándo |
|--------|--------|
| `ronda_iniciada` | Al repartir (juego solo) o al llamar `startRound` (sala) |
| `apuesta_realizada` | Al confirmar apuesta en el juego solo |
| `accion_jugador` | Pedir / plantarse / doblar / dividir / rendirse (ambos modos) |
| `mano_resuelta` | Al terminar cada ronda en el juego solo |
| `blackjack` | Cuando se detecta blackjack natural |
| `saldo_agotado` | Cuando la banca llega a 0 tras una ronda |
| `sala_creada` | Al crear una sala multijugador |
| `sala_unida` | Al entrar a una sala como jugador o espectador |
| `amigo_agregado` | Al aceptar una solicitud de amistad |
| `transferencia` | Tras una transferencia exitosa |
| `bono_conversion` | Tras reclamar el bono de conversión de cuenta anónima |

### Analytics — user properties

| Propiedad | Valor |
|-----------|-------|
| `tipo_cuenta` | `anonimo` o `permanente` |
| `tema` | nombre del tema activo (e.g. `verde`, `rojo`) |

### Navegación de pantallas
El `TelemetriaRouterObserver` registra automáticamente cada pantalla al navegar.

## Privacidad
Toggle «Compartir datos de uso» en el panel de ajustes. Llama a
`setAnalyticsCollectionEnabled` y `setCrashlyticsCollectionEnabled`.
Sin persistencia entre sesiones (mejora futura con `shared_preferences`).

## Archivos clave

- `lib/core/telemetria/` — módulo completo de telemetría
- `lib/core/router/router_observer.dart` — observer de navegación
- `lib/main.dart` — hooks de error global
- `lib/app.dart` — listeners de uid y tema
