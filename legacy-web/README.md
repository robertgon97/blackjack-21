# Blackjack 21 — Versión original (JS vanilla)

Esta carpeta contiene el juego de Blackjack original, desarrollado en **HTML + JavaScript puro
(ES vanilla)** con **Tailwind CSS**. Fue la primera versión del proyecto, desplegada en GitHub Pages.

Se archivó aquí cuando el proyecto migró a una **app multiplataforma en Flutter** (la raíz del repo).

## Cómo correr la versión web original

```bash
cd legacy-web
npm install          # solo la 1ª vez (Tailwind CLI)
npm run build:css    # compilar styles.css desde src/input.css
python -m http.server 8765   # servir en http://localhost:8765
```

## Cómo correr los tests JS originales

```bash
cd legacy-web
node tests/test.js   # 35 asserts de lógica
```

## Estructura

```
legacy-web/
├── index.html          ← juego completo (carga los scripts en orden)
├── styles.css          ← CSS generado por Tailwind (no editar a mano)
├── favicon.svg         ← ícono ♠
├── og-image.png        ← imagen para redes sociales (1200×630)
├── tailwind.config.js
├── package.json
├── src/
│   └── input.css       ← fuente del CSS (Tailwind + CSS propio)
├── js/
│   ├── config.js       ← reglas configurables
│   ├── cartas.js       ← puntos, shoe, Hi-Lo, probabilidades
│   ├── estrategia.js   ← estrategia básica óptima
│   ├── audio.js        ← sonidos con Web Audio API
│   ├── stats.js        ← niveles y logros
│   ├── ui.js           ← render del tapete y cartas
│   ├── juego.js        ← flujo de la ronda
│   └── main.js         ← cablea botones e inicia el juego
└── tests/
    └── test.js         ← 35 asserts (DOM simulado en Node)
```

La lógica de `cartas.js`, `estrategia.js` y `juego.js` fue traducida a Dart en
`lib/features/game/domain/` como parte de la migración a Flutter.
