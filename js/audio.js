// ============================================================
//  SONIDOS (generados por código con la Web Audio API)
//  Sin archivos externos: creamos los tonos al vuelo. Incluye
//  un "ambiente" de fondo opcional muy suave.
// ============================================================
let audioCtx = null;
let silencio = false;
let ambienteActivo = false;
let ambienteNodos = null;

function getCtx() {
  if (!audioCtx) {
    try {
      audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    } catch (e) {
      audioCtx = null;
    }
  }
  if (audioCtx && audioCtx.state === "suspended") audioCtx.resume();
  return audioCtx;
}

// Reproduce un tono simple
function tono(freq, inicio = 0, dur = 0.12, tipo = "sine", vol = 0.2) {
  const ctx = getCtx();
  if (!ctx || silencio) return;
  const t0 = ctx.currentTime + inicio;
  const osc = ctx.createOscillator();
  const g = ctx.createGain();
  osc.type = tipo;
  osc.frequency.value = freq;
  g.gain.setValueAtTime(0.0001, t0);
  g.gain.linearRampToValueAtTime(vol, t0 + 0.01);
  g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
  osc.connect(g).connect(ctx.destination);
  osc.start(t0);
  osc.stop(t0 + dur + 0.02);
}

// Sonidos concretos del juego
const sonidoCarta = () => { tono(420, 0, 0.07, "triangle", 0.18); tono(300, 0.02, 0.06, "triangle", 0.12); };
const sonidoFicha = () => { tono(900, 0, 0.05, "square", 0.12); tono(1250, 0.03, 0.05, "square", 0.1); };
const sonidoGanar = () => { [523, 659, 784].forEach((f, i) => tono(f, i * 0.1, 0.18, "sine", 0.2)); };
const sonidoBlackjack = () => { [523, 659, 784, 1047].forEach((f, i) => tono(f, i * 0.09, 0.22, "sine", 0.22)); };
const sonidoPerder = () => { tono(300, 0, 0.25, "sawtooth", 0.14); tono(200, 0.14, 0.32, "sawtooth", 0.14); };
const sonidoEmpate = () => { tono(440, 0, 0.15, "sine", 0.14); };
const sonidoBarajar = () => { for (let i = 0; i < 8; i++) tono(600 + Math.random() * 600, i * 0.04, 0.05, "triangle", 0.06); };
const sonidoRendirse = () => { tono(330, 0, 0.18, "sine", 0.12); tono(247, 0.1, 0.22, "sine", 0.12); };
const sonidoLogro = () => { [659, 880, 1047, 1319].forEach((f, i) => tono(f, i * 0.08, 0.2, "triangle", 0.18)); };
const sonidoMoneda = () => { tono(1318, 0, 0.06, "square", 0.12); tono(1760, 0.05, 0.08, "square", 0.1); };

// Ambiente de casino: dos tonos graves muy suaves de fondo
function alternarAmbiente(activar) {
  const ctx = getCtx();
  if (!ctx) return;
  ambienteActivo = activar;
  if (activar && !ambienteNodos) {
    const g = ctx.createGain();
    g.gain.value = 0.015;
    const o1 = ctx.createOscillator();
    o1.type = "sine"; o1.frequency.value = 110;
    const o2 = ctx.createOscillator();
    o2.type = "sine"; o2.frequency.value = 138;
    o1.connect(g); o2.connect(g); g.connect(ctx.destination);
    o1.start(); o2.start();
    ambienteNodos = { o1, o2, g };
  } else if (!activar && ambienteNodos) {
    try { ambienteNodos.o1.stop(); ambienteNodos.o2.stop(); } catch (e) {}
    ambienteNodos = null;
  }
}
