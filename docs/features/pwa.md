# Feature: PWA (web instalable + arranque con marca)

> Sub-PR **11a** de la Fase 11 (monetización y pulido) del
> [plan maestro](../plans/00-app-multiplataforma.md). Las otras piezas de la fase son **push** (FCM) y
> **anuncios** (AdMob), en sub-PRs aparte.

## Propósito

Hacer que la versión web se comporte como una app: **instalable** (añadir a pantalla de inicio), con
identidad de marca al arrancar y sin el "flash en blanco" mientras carga el bundle de Flutter. Aborda la
parte web del issue #68 (arranque "seco").

## Qué incluye

- **`web/manifest.json`**: colores de marca (`theme_color` `#0B6E3B`, `background_color` `#0E3A24`) en vez
  del azul de Flutter por defecto. Nombre, descripción, `display: standalone` e iconos ya estaban.
- **`web/index.html`**:
  - `meta theme-color` (barra del navegador/PWA con el verde de marca).
  - **Pantalla de carga** (`#loading`): logo 🃏 + "Blackjack 21" + spinner sobre un gradiente verde, que
    cubre el blanco inicial mientras se descarga el bundle. Se desvanece y se elimina en el evento
    `flutter-first-frame` (cuando Flutter pinta el primer frame).
  - `apple-mobile-web-app-status-bar-style` ajustado para iOS web.
- El **service worker** (offline básico del *app shell*) lo genera `flutter build web` automáticamente
  (`flutter_service_worker.js`); no requiere código propio.

## No incluye

- **Iconos propios**: siguen siendo los placeholders de Flutter (`web/icons/`). Reemplazarlos por un
  icono de marca es un paso de *assets* pendiente (aporta el diseño; no bloquea la instalación).
- Offline de datos (Firestore ya cachea su propio estado); aquí solo el *app shell*.

## Cómo probarlo

- `flutter build web --release` compila e incluye el `index.html` con la pantalla de carga.
- En el navegador: al abrir, se ve el logo + spinner hasta que carga la app (sin flash blanco); el
  navegador ofrece "Instalar" / "Añadir a pantalla de inicio"; instalada, abre en modo standalone con los
  colores de marca.

## Pendiente de la Fase 11

- **Push** (FCM): notificaciones de retención (nivel, racha). Android/Web; iOS tras Apple Developer.
- **Anuncios** (AdMob): *rewarded* "ver anuncio → créditos"; integración con IDs de prueba hasta tener
  cuenta AdMob.
