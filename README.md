# ♠ Blackjack 21 ♥

Un juego de Blackjack (21) completo hecho con **HTML, CSS y JavaScript puro** (sin frameworks ni dependencias). Pensado para jugar y para aprender, con el dinero siempre a la vista.

## ✨ Características

### Reglas y jugadas
- Pedir, plantarse, **doblar**, **dividir** (split, hasta 4 manos), **rendirse** y **seguro**.
- **Mazo múltiple** (shoe de 1 a 8 barajas) con rebaraje automático.
- Pago de Blackjack configurable (**3:2** o **6:5**).
- Variantes de casa: **H17** (crupier pide en 17 suave) y **empuje en 22**.
- Límites de mesa (apuesta mínima/máxima).

### Dinero y progresión
- Banca con movimiento del dinero en vivo (apuesta, ganancia, pérdida).
- Botones de apuesta rápida (**repetir** y **×2**).
- **Estadísticas**, **historial** de manos, **niveles** y **logros** desbloqueables.
- Préstamo al quedarte sin dinero.

### Visual y experiencia
- Reparto carta por carta con suspenso y **volteo 3D** de la carta del crupier.
- **Fichas de casino** animadas que vuelan al apostar.
- **4 temas** (Clásico, Noche, Rubí, Oscuro) y diseño **responsive** para móvil.
- Sonidos generados por código (Web Audio API) + ambiente de fondo opcional.

### Aprendizaje
- **Consejo de estrategia básica** óptima en vivo.
- **Modo entrenamiento** que avisa cuando te desvías de la jugada óptima.
- **Contador Hi-Lo** y **probabilidad de pasarte** en tiempo real.
- Tutorial interactivo.

## 🚀 Cómo jugar

Abre `index.html` en el navegador. Para evitar problemas con rutas locales, lo más cómodo es servirlo:

```bash
# Python
python -m http.server 8000
# luego abre http://localhost:8000
```

## 🧱 Estructura

```
blackjack/
├── index.html
├── styles.css
├── js/
│   ├── config.js      # reglas configurables
│   ├── cartas.js      # mazo, puntos, conteo, probabilidades
│   ├── estrategia.js  # estrategia básica óptima
│   ├── audio.js       # sonidos y ambiente
│   ├── stats.js       # estadísticas, historial, logros
│   ├── ui.js          # render, animaciones, paneles
│   ├── juego.js       # flujo principal del juego
│   └── main.js        # conexión de la interfaz
└── tests/
    └── test.js        # tests automatizados
```

## 🧪 Tests

La lógica del juego está cubierta por tests que corren en Node con un DOM simulado:

```bash
node tests/test.js
```
