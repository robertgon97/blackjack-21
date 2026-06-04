# CLAUDE.md — Guía del proyecto Blackjack 21

Contexto para asistentes de IA (y para el autor) que trabajen en este repo. Léelo antes de tocar código.

## Qué es

Juego de Blackjack (21) completo en **HTML + CSS + JavaScript puro (ES vanilla)**.
- **Sin frameworks, sin bundler, sin dependencias de runtime.** Se ejecuta abriendo `index.html` (idealmente servido por HTTP, ver abajo).
- **Sin paso de build.** Lo que editas es lo que corre.
- Node solo se usa para correr los **tests** (DOM simulado), nunca para servir el juego.
- Idioma del código, comentarios y UI: **español** (con acentos correctos).

## Cómo ejecutar y verificar

```bash
# Servir el juego (recomendado sobre abrir file:// por temas de rutas)
python -m http.server 8765
# luego abrir http://localhost:8765

# Correr los tests (desde la carpeta blackjack/)
node tests/test.js          # 35 asserts de lógica
```

Nota: la extensión "Claude in Chrome" NO puede navegar a `file://` (le antepone `https://`). Para inspeccionar en el navegador, **levantar el servidor Python** y navegar a `http://localhost:8765`. Acordarse de cerrar el servidor al terminar.

Verificación rápida de sintaxis tras editar JS:
```bash
for f in js/*.js; do node --check "$f"; done
```

## Arquitectura: módulos cargados como scripts clásicos

`index.html` carga los JS con `<script>` clásicos (NO ES modules), **en este orden**, al final del `<body>`:

```
config.js → cartas.js → estrategia.js → audio.js → stats.js → ui.js → juego.js → main.js
```

**Clave:** son scripts clásicos, así que comparten el **global lexical scope**. Un `const`/`let`/`function` de nivel superior en un archivo es visible en los siguientes. **El orden de carga importa** y **no debe haber nombres duplicados** entre archivos. Esto se eligió a propósito en vez de ES modules porque permite abrir el juego con `file://` sin problemas de CORS.

### Responsabilidad de cada módulo

| Archivo | Qué contiene | Toca el DOM |
|---------|--------------|:-----------:|
| `config.js` | Objeto global `config` con todas las reglas configurables. | No |
| `cartas.js` | Shoe (mazo múltiple), barajar, `sacarCarta`, `calcularPuntos`, `infoMano` (total + si es "suave"), `valorSplit`/`mismoValorSplit`, conteo Hi-Lo (`contar`, `conteoVerdadero`), `probabilidadPasarse`. | No |
| `estrategia.js` | Estrategia básica óptima. `consejoEstrategia(cartas, cartaCrupier, opc)` → `"pedir"/"plantarse"/"doblar"/"dividir"/"rendirse"`. `nombreJugada()`. | No |
| `audio.js` | Sonidos generados con Web Audio API (sin archivos). `silencio`, `tono()`, `sonidoCarta/Ficha/Ganar/...`, `alternarAmbiente()`. | No |
| `stats.js` | `stats` (objeto), `historial` (array), niveles (`NIVELES`, `nivelActual`), logros (`LOGROS`, `logrosDesbloqueados`, `revisarLogros`). | No |
| `ui.js` | TODO lo que pinta: `$()` helper, render de cartas (incl. volteo 3D), `construirGruposJugador`, `animarFichaVolando`, `aplicarTema`, paneles, `toast`. Mantiene `filasJugador`/`infosJugador` (refs a las manos en pantalla). | Sí |
| `juego.js` | Estado y flujo principal. Reparto, turnos, reglas, dinero, resolución, integración de stats/conteo/estrategia. | Sí (vía `$` y helpers de ui) |
| `main.js` | Cablea los botones del HTML con las funciones, panel de Ajustes, tutorial, desplegable de tema. Llama a `iniciarJuego()` al final. | Sí |

## Estado del juego (vive en `juego.js`)

```js
banca            // dinero total del jugador
apuesta          // apuesta base elegida antes de repartir
ultimaApuesta    // para el botón "Repetir"
manos            // ARRAY de manos del jugador (por los splits):
                 //   { cartas:[], apuesta, doblada, asPartido, rendida }
indiceMano       // qué mano se está jugando (0-based)
manoCrupier      // cartas del crupier (array)
rondaActiva      // ¿hay mano en curso?
animando         // ¿se están repartiendo cartas? Bloquea clics.
crupierOculto    // ¿la 1ª carta del crupier sigue boca abajo?
seguro           // dinero apostado en el "seguro"
cartaOcultaEl    // referencia al elemento volteable del crupier
```

**`manos` es siempre un array** (incluso con una sola mano). Cualquier lógica nueva debe iterar sobre `manos`, no asumir una mano única. `indiceMano` apunta a la mano activa.

## Flujo de una ronda (todo asíncrono con `async/await`)

El reparto es carta por carta con pausas (`esperar(ms)`) para dar suspenso. Bandera `animando` evita clics a destiempo.

```
repartir()
  → (si necesita) crearShoe()
  → descuenta apuesta de banca
  → reparte: jugador, crupier(oculta), jugador, crupier(visible)  [una por una]
  → ¿crupier muestra As? → ofrece seguro (zona-seguro) ; si no → iniciarTurnoJugador()

tomarSeguro(bool) → iniciarTurnoJugador()

iniciarTurnoJugador()
  → si crupier tiene BJ natural → revela + finalizarRonda()
  → si jugador tiene BJ natural → revela + finalizarRonda()  (paga 3:2)
  → si no → jugarManoActiva()

jugarManoActiva()  (se llama para cada mano, también tras split)
  → si la mano viene de split con 1 carta, le da la 2ª
  → si "as partido": 1 carta y auto-avanza
  → si 21: auto-avanza
  → si no: muestra botones, calcula consejo + probabilidad, espera input

Acciones del jugador: pedirCarta / doblar / dividir / rendirse / plantarse
  → cada una termina llamando avanzarMano()

avanzarMano()
  → si quedan manos → siguiente jugarManoActiva()
  → si no → jugarCrupier()

jugarCrupier()
  → revela carta oculta (volteo 3D) y la cuenta para el Hi-Lo
  → mientras debePedirCrupier() → saca carta (carta por carta)
  → finalizarRonda()

finalizarRonda()
  → resuelve seguro, resuelve cada mano (resolverMano), mueve dinero
  → registra stats + historial, revisa logros, muestra resultado
  → banca<=0 → zona-prestamo ; si no → zona-nueva
```

## Reglas configurables (`config`)

`numBarajas`, `pagoBlackjack` (1.5 = 3:2, 1.2 = 6:5), `crupierPideEn17Suave` (H17),
`empujeEn22` (crupier 22 = empate), `apuestaMin`/`apuestaMax`, `permitirRendirse`,
`modoEntrenamiento`, `mostrarConteo`, `mostrarProbabilidad`, `bancaInicial`.

Se editan desde el panel de Ajustes (⚙️). Cambiarlas re-baraja el shoe. La resolución de manos (`resolverMano` en `juego.js`) y la regla del crupier (`debePedirCrupier`) leen `config`.

## Conteo Hi-Lo: cuándo se cuenta una carta

`contar(carta)` se llama **cuando una carta se hace visible**:
- carta del jugador → en `darCartaJugador`
- carta visible del crupier → en `darCartaCrupierVisible`
- carta oculta del crupier → **al revelarla** (`revelarCrupier`), NO al repartirla
- cartas que roba el crupier → al sacarlas

Si añades nuevas formas de mostrar cartas, recuerda llamar a `contar()`.

## Tests

`tests/test.js` carga los módulos reales (concatenados, sin `main.js`) dentro de un **DOM simulado** en un contexto `vm` de Node, y verifica lógica pura: puntos, split, conteo, shoe, probabilidades, estrategia básica, reglas (empuje22, rendirse, H17, pago 3:2/6:5) y un reparto completo.

Para **forzar cartas concretas** en un test: sobreescribir `shoe` y poner `totalShoe = shoe.length` (si no, `necesitaBarajar()` lo regenera). Orden de `pop()` en el reparto: `player1, crupierOculta, player2, crupierVisible` (la última del array sale primero). La carta visible del crupier es `manoCrupier[1]`.

Si agregas lógica nueva, **añade su test** en el bloque `this.__run` de `tests/test.js`.

## Gotchas / decisiones aprendidas (no repetir errores)

1. **Especificidad CSS:** la regla de los iconos del header es `.header-botones > button` (hijo directo) a propósito. Si usas `.header-botones button` (descendiente), pisa al botón del desplegable de tema (`.dropdown-toggle`, que está anidado) y lo aplasta a 38px.
2. **Volteo 3D de la carta oculta:** las caras (`.carta-inner .cara`) llevan `animation: none`. La animación de entrada `aparecer` anima `transform` y pisaba el `rotateY(180deg)`, haciendo que la carta parpadeara (se veía la cara por 0.3s). No volver a ponerle animación a esas caras.
3. **Desplegable de tema:** es un dropdown **personalizado** (no `<select>`), porque el desplegable nativo se ve feo y no es estilizable en Edge/Chrome. Vive en `index.html` (`#dd-tema`), con CSS `.dropdown*` y JS en `main.js` (`seleccionarTema`, abrir/cerrar, cerrar al clic afuera).
4. **El botón "disponible" (brillo verde)** en Doblar/Dividir indica que la jugada es **legal**, no que sea óptima. Puede competir visualmente con el consejo de estrategia (pendiente de pulir, ver abajo).
5. **Scripts clásicos:** no usar `import/export` ni `type="module"`; rompería el `file://` y el modelo de scope compartido. No duplicar nombres globales entre archivos.
6. **Navegador:** la extensión no abre `file://`; servir con `python -m http.server` para inspeccionar.

## Git / despliegue

- Repo: `robertgon97/blackjack-21` (privado), rama `main`.
- Subido vía **HTTPS** con credencial de `gh` (hay 2 cuentas de GitHub; la activa quedó en `robertgon97`). Si falla el push por auth: `gh auth switch --user robertgon97`.
- Flujo: `git add . && git commit -m "..." && git push`.

## SEO / compartir en redes

- `index.html` tiene meta tags **Open Graph + Twitter Card + descripción + canonical + theme-color**.
- `favicon.svg`: ícono (♠ sobre verde).
- `og-image.png` (1200×630): imagen de preview al compartir. Se generó dibujándola en un `<canvas>` (sin dependencias). Si necesitas regenerarla, el método fue: dibujar en canvas vía JS en el navegador → `toDataURL('image/png')` → descargar. Mantener el ratio **1.91:1** y las URLs absolutas a `robertgon97.github.io/blackjack-21/`.
- Las URLs de `og:image`/`canonical` son **absolutas** (las redes lo exigen). Si cambia el dominio/repo, actualizarlas.

## Despliegue web (GitHub Pages) + CI

- **GitHub Pages** sirve la rama `main` (carpeta raíz) en `https://robertgon97.github.io/blackjack-21/`. Cada push a `main` redespliega solo.
- **CI** (`.github/workflows/tests.yml`): en cada push/PR a `main` valida sintaxis JS y corre `node tests/test.js`. Si falla, el commit queda en rojo.
- Subir archivos de workflow requiere que el token de `gh` tenga el scope **`workflow`** (`gh auth refresh -h github.com -s workflow`).

## Pendiente / ideas no implementadas

- **Persistencia con `localStorage`** (banca, stats, logros entre sesiones). NO implementado a propósito (se pidió dejarlo para después).
- **Atajos de teclado** (P/S/D/R/espacio).
- **Modo entrenamiento:** que el brillo verde marque solo la jugada óptima (no todas las legales).
- Otras ideas sugeridas: side bets (21+3, pares perfectos), confeti al ganar, voz del crupier (SpeechSynthesis), gráfico de la banca, PWA instalable, accesibilidad ARIA.

## Convenciones

- Comentarios y nombres en español, con acentos correctos.
- Funciones globales (scope compartido); no introducir módulos/namespaces sin migrar todo.
- Mantener la separación: `cartas/estrategia/stats/audio` NO tocan el DOM; `ui` pinta; `juego` orquesta; `main` cablea.
