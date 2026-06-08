# Documentación — Blackjack 21 App

Esta carpeta es la **fuente de verdad** del proyecto: aquí viven las reglas de negocio, las decisiones
de arquitectura y la ficha de cada feature. Si el código y un documento de `reglas-negocio/` difieren,
**el documento manda** y se corrige el código.

> **Regla de oro para quien programe (humano o IA):** antes de tocar una feature, lee su ficha en
> [`features/`](features/) y las reglas relacionadas en [`reglas-negocio/`](reglas-negocio/). Al
> terminar una fase o feature, **actualiza la documentación correspondiente** — es parte de la
> definición de "hecho".

## Índice

### 📋 Planes
- [`plans/00-app-multiplataforma.md`](plans/00-app-multiplataforma.md) — Plan maestro: migración del
  juego web a app multiplataforma (Flutter + Firebase).

### 🏗️ Arquitectura
- [`arquitectura/vision-general.md`](arquitectura/vision-general.md) — Capas, organización
  feature-first, flujo de datos y abstracción de proveedores externos.
- [`arquitectura/modelo-datos.md`](arquitectura/modelo-datos.md) — Colecciones de Firestore, campos y
  relaciones.
- [`arquitectura/seguridad.md`](arquitectura/seguridad.md) — Reglas de Firestore y validaciones en
  Cloud Functions.
- [`arquitectura/flutter-recursos-oficiales.md`](arquitectura/flutter-recursos-oficiales.md) —
  Recomendaciones oficiales de Flutter: Games Toolkit, patrón FirestoreController para multijugador,
  integración de AdMob (rewarded ads), logros, paquetes por fase.
- [`arquitectura/ci-cd-y-firmas.md`](arquitectura/ci-cd-y-firmas.md) —
  CI/CD completo: firma Android (keystore + GitHub Secrets + build.gradle), firma iOS, App Bundle
  vs APK, flavors dev/prod, deep links `/join/CODE`, renderer web (CanvasKit vs WASM).
- [`arquitectura/testing-strategy.md`](arquitectura/testing-strategy.md) —
  Pirámide de tests: unit (✅ 32 tests), widget (Fase 2), integration (Fase 5), code coverage en
  CI, performance 60fps, accesibilidad.

### 💼 Reglas de negocio
- [`reglas-negocio/reglas-del-juego.md`](reglas-negocio/reglas-del-juego.md) — Reglas del Blackjack y
  variantes de casa configurables.
- [`reglas-negocio/creditos-y-economia.md`](reglas-negocio/creditos-y-economia.md) — Economía de
  créditos: fuentes, bonos, límites.
- [`reglas-negocio/salas-y-multijugador.md`](reglas-negocio/salas-y-multijugador.md) — Salas, turnos,
  temporizadores y roles.
- [`reglas-negocio/social.md`](reglas-negocio/social.md) — Amigos, invitaciones y transferencias.

### 📝 Historial de trabajo
- [`errores-y-correcciones.md`](errores-y-correcciones.md) — registro de errores del asistente y sus correcciones.

### 🧩 Features
- [`features/_plantilla-feature.md`](features/_plantilla-feature.md) — Plantilla para documentar cada
  feature nueva.
- Las fichas concretas (`auth.md`, `game.md`, `wallet.md`, `friends.md`, `rooms.md`, `comms.md`, …) se
  agregan **junto con** cada feature.

## Estado del proyecto

El proyecto está en **migración** desde una versión web vanilla (HTML + JS) hacia una app Flutter
multiplataforma. La versión original se conserva en [`../legacy-web/`](../legacy-web/) como referencia.

El avance se organiza por fases (ver el plan maestro). Cada fase cierra con: `flutter analyze` +
`flutter test` en verde, documentación actualizada y un commit.
