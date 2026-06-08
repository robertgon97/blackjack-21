// ============================================================
//  TESTS AUTOMATIZADOS del Blackjack
//  Carga los módulos reales en un DOM simulado y verifica la
//  lógica (puntos, estrategia, shoe, conteo, reglas, flujo).
//
//  Ejecutar:  node tests/test.js   (desde la carpeta blackjack)
// ============================================================
const fs = require("fs");
const path = require("path");
const vm = require("vm");

// ---- DOM simulado mínimo ----
class CL {
  constructor() { this.s = new Set(); }
  add(c) { this.s.add(c); } remove(c) { this.s.delete(c); }
  toggle(c, f) { if (f === undefined) { this.s.has(c) ? this.s.delete(c) : this.s.add(c); } else { f ? this.s.add(c) : this.s.delete(c); } }
  contains(c) { return this.s.has(c); }
}
class El {
  constructor() {
    this.disabled = false; this.textContent = ""; this._html = ""; this.value = "";
    this.checked = false; this.dataset = {}; this.children = []; this.className = "";
    this.classList = new CL(); this.parentElement = null; this.style = {}; this._l = {};
  }
  addEventListener(ev, fn) { this._l[ev] = fn; }
  appendChild(c) { this.children.push(c); c.parentElement = this; return c; }
  remove() { if (this.parentElement) this.parentElement.children = this.parentElement.children.filter((x) => x !== this); }
  getBoundingClientRect() { return { left: 0, top: 0, width: 0, height: 0 }; }
  get innerHTML() { return this._html; }
  set innerHTML(v) { this._html = v; if (v === "") this.children = []; }
  querySelectorAll() { return []; }
}
const reg = {};
const fichas = [10, 25, 50, 100].map((v) => { const e = new El(); e.dataset.valor = String(v); return e; });
const document = {
  body: new El(),
  getElementById(id) { if (!reg[id]) reg[id] = new El(); return reg[id]; },
  createElement() { return new El(); },
  querySelectorAll(sel) { return sel === ".ficha" ? fichas : []; },
};
class FA {
  constructor() { this.currentTime = 0; this.state = "running"; this.destination = {}; }
  resume() {} createOscillator() { return { type: "", frequency: { value: 0 }, connect(n) { return n; }, start() {}, stop() {} }; }
  createGain() { return { gain: { value: 0, setValueAtTime() {}, linearRampToValueAtTime() {}, exponentialRampToValueAtTime() {} }, connect(n) { return n; } }; }
}
const sandbox = {
  document, window: { AudioContext: FA, webkitAudioContext: FA },
  setTimeout: (fn) => { fn(); }, requestAnimationFrame: (fn) => fn(),
  Math, console, Promise, Number, Array, Set, JSON,
};

// ---- Cargar y concatenar los módulos (sin main.js) ----
const base = path.join(__dirname, "..", "js");
const archivos = ["config.js", "cartas.js", "estrategia.js", "audio.js", "stats.js", "ui.js", "juego.js"];
let fuente = archivos.map((f) => fs.readFileSync(path.join(base, f), "utf8")).join("\n");

// ---- Test runner sencillo ----
let pasados = 0, fallidos = 0;
const fallos = [];
function ok(nombre, cond) { if (cond) { pasados++; } else { fallidos++; fallos.push(nombre); } }
sandbox.ok = ok;

// ---- Código de tests (se ejecuta en el MISMO ámbito que los módulos) ----
const tests = `
this.__run = (async () => {
  // --- Puntos ---
  ok("As+K = 21", calcularPuntos([{valor:"A",palo:"♠"},{valor:"K",palo:"♥"}]) === 21);
  ok("A+A+9 = 21", calcularPuntos([{valor:"A"},{valor:"A"},{valor:"9"}]) === 21);
  ok("K+Q+5 = 25 (pasado)", calcularPuntos([{valor:"K"},{valor:"Q"},{valor:"5"}]) === 25);
  ok("A+6 es suave 17", infoMano([{valor:"A"},{valor:"6"}]).suave === true && infoMano([{valor:"A"},{valor:"6"}]).total === 17);
  ok("A+6+10 NO es suave", infoMano([{valor:"A"},{valor:"6"},{valor:"10"}]).suave === false);

  // --- Split ---
  ok("10 y K se dividen", mismoValorSplit({valor:"10"},{valor:"K"}) === true);
  ok("8 y 9 NO se dividen", mismoValorSplit({valor:"8"},{valor:"9"}) === false);

  // --- Conteo Hi-Lo ---
  ok("conteo 5 = +1", valorConteo({valor:"5"}) === 1);
  ok("conteo K = -1", valorConteo({valor:"K"}) === -1);
  ok("conteo 8 = 0", valorConteo({valor:"8"}) === 0);

  // --- Shoe ---
  config.numBarajas = 6; crearShoe();
  ok("shoe 6 barajas = 312 cartas", shoe.length === 312);
  ok("totalShoe registrado", totalShoe === 312);

  // --- Probabilidad de pasarse ---
  crearShoe();
  const p12 = probabilidadPasarse([{valor:"10"},{valor:"2"}]); // 12
  const p20 = probabilidadPasarse([{valor:"10"},{valor:"10"}]); // 20
  ok("12 tiene menos riesgo que 20", p12 < p20);
  ok("20 tiene alto riesgo (>0.6)", p20 > 0.6);

  // --- Estrategia básica ---
  const opcSi = {puedeDoblar:true,puedeDividir:true,puedeRendirse:true};
  const opcNoR = {puedeDoblar:true,puedeDividir:true,puedeRendirse:false};
  ok("8,8 -> dividir", consejoEstrategia([{valor:"8"},{valor:"8"}], {valor:"6"}, opcSi) === "dividir");
  ok("10,10 -> plantarse", consejoEstrategia([{valor:"10"},{valor:"Q"}], {valor:"6"}, opcSi) === "plantarse");
  ok("A,A -> dividir", consejoEstrategia([{valor:"A"},{valor:"A"}], {valor:"6"}, opcSi) === "dividir");
  ok("11 vs 6 -> doblar", consejoEstrategia([{valor:"5"},{valor:"6"}], {valor:"6"}, opcSi) === "doblar");
  ok("16 vs 10 sin rendir -> pedir", consejoEstrategia([{valor:"10"},{valor:"6"}], {valor:"10"}, opcNoR) === "pedir");
  ok("16 vs 10 con rendir -> rendirse", consejoEstrategia([{valor:"10"},{valor:"6"}], {valor:"10"}, opcSi) === "rendirse");
  ok("A,7 vs 9 -> pedir", consejoEstrategia([{valor:"A"},{valor:"7"}], {valor:"9"}, opcSi) === "pedir");
  ok("A,7 vs 6 -> doblar", consejoEstrategia([{valor:"A"},{valor:"7"}], {valor:"6"}, opcSi) === "doblar");
  ok("20 duro -> plantarse", consejoEstrategia([{valor:"10"},{valor:"K"}], {valor:"5"}, {puedeDividir:false}) === "plantarse");

  // --- Reglas: empuje en 22 ---
  config.empujeEn22 = true;
  manoCrupier = [{valor:"K"},{valor:"7"},{valor:"5"}]; // 22
  manos = [{cartas:[{valor:"10"},{valor:"10"}], apuesta:10, doblada:false, rendida:false}];
  ok("empuje22: crupier 22 = empate", resolverMano(manos[0]).estado === "empate");
  config.empujeEn22 = false;
  ok("sin empuje22: crupier 22 = ganar", resolverMano(manos[0]).estado === "ganar");

  // --- Reglas: rendirse devuelve la mitad ---
  manos = [{cartas:[{valor:"10"},{valor:"6"}], apuesta:100, doblada:false, rendida:true}];
  ok("rendirse devuelve la mitad", resolverMano(manos[0]).ganancia === 50);

  // --- Reglas: H17 ---
  config.crupierPideEn17Suave = true;
  manoCrupier = [{valor:"A"},{valor:"6"}]; // soft 17
  ok("H17: crupier pide con 17 suave", debePedirCrupier() === true);
  config.crupierPideEn17Suave = false;
  ok("S17: crupier se planta con 17 suave", debePedirCrupier() === false);
  manoCrupier = [{valor:"10"},{valor:"6"}]; // 16 duro
  ok("crupier pide con 16", debePedirCrupier() === true);

  // --- Pago Blackjack 3:2 vs 6:5 ---
  config.pagoBlackjack = 1.5;
  manos = [{cartas:[{valor:"A"},{valor:"K"}], apuesta:100, doblada:false, rendida:false}];
  manoCrupier = [{valor:"9"},{valor:"7"}]; // 16, jugador gana con BJ
  ok("BJ 3:2 paga 250 (100+150)", resolverMano(manos[0]).ganancia === 250);
  config.pagoBlackjack = 1.2;
  ok("BJ 6:5 paga 220 (100+120)", resolverMano(manos[0]).ganancia === 220);
  config.pagoBlackjack = 1.5;

  // --- Flujo completo: repartir no rompe y deduce la apuesta ---
  config.empujeEn22 = false;
  banca = 1000; apuesta = 50; rondaActiva = false; animando = false;
  await repartir();
  ok("repartir reparte 2 cartas al jugador", manos[0].cartas.length === 2);
  ok("repartir reparte 2 al crupier", manoCrupier.length === 2);
  ok("repartir descuenta la apuesta (banca < 1000)", banca < 1000);
  ok("ronda activa o ya resuelta", typeof rondaActiva === "boolean");

  return true;
})();
`;

vm.createContext(sandbox);
vm.runInContext(fuente + tests, sandbox);

sandbox.__run
  .then(() => {
    console.log(`\n  ✅ Pasados: ${pasados}`);
    console.log(`  ❌ Fallidos: ${fallidos}`);
    if (fallos.length) { console.log("\n  Tests fallidos:"); fallos.forEach((f) => console.log("   - " + f)); process.exitCode = 1; }
    else console.log("\n  🎉 Todos los tests pasaron.");
  })
  .catch((e) => { console.error("Error ejecutando tests:", e); process.exitCode = 1; });
