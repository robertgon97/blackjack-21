// ============================================================
//  ESTADÍSTICAS, HISTORIAL Y LOGROS
//  Lleva la cuenta de cómo te va y desbloquea logros.
// ============================================================
const stats = {
  jugadas: 0,
  ganadas: 0,
  perdidas: 0,
  empates: 0,
  blackjacks: 0,
  rachaActual: 0,   // positivo = victorias seguidas, negativo = derrotas
  mejorRacha: 0,
  mayorBanca: config.bancaInicial,
  errores: 0,       // jugadas que se desviaron de la estrategia (modo entrenamiento)
  prestamos: 0,     // veces que pediste préstamo
};

const historial = []; // últimas manos: { resultado, neto }

// Registra el resultado de UNA mano para las estadísticas
function registrarResultado(estado, esBlackjack) {
  stats.jugadas++;
  if (estado === "ganar") {
    stats.ganadas++;
    stats.rachaActual = stats.rachaActual >= 0 ? stats.rachaActual + 1 : 1;
    if (esBlackjack) stats.blackjacks++;
  } else if (estado === "perder") {
    stats.perdidas++;
    stats.rachaActual = stats.rachaActual <= 0 ? stats.rachaActual - 1 : -1;
  } else {
    stats.empates++;
    // el empate no rompe la racha
  }
  if (stats.rachaActual > stats.mejorRacha) stats.mejorRacha = stats.rachaActual;
}

// Guarda el resumen de la ronda en el historial
function registrarHistorial(neto) {
  historial.unshift({ neto, fecha: Date.now ? null : null });
  if (historial.length > 12) historial.pop();
}

function porcentajeVictorias() {
  const decididas = stats.ganadas + stats.perdidas;
  if (decididas === 0) return 0;
  return Math.round((stats.ganadas / decididas) * 100);
}

// ---- NIVEL según la mayor banca alcanzada ----
const NIVELES = [
  { nombre: "Novato", min: 0 },
  { nombre: "Aficionado", min: 1500 },
  { nombre: "Jugador", min: 2500 },
  { nombre: "Tiburón", min: 5000 },
  { nombre: "Alto Roller", min: 10000 },
  { nombre: "Leyenda", min: 25000 },
];
function nivelActual() {
  let nivel = NIVELES[0];
  for (const n of NIVELES) {
    if (stats.mayorBanca >= n.min) nivel = n;
  }
  return nivel;
}

// ---- LOGROS ----
const LOGROS = [
  { id: "primera",   nombre: "🎉 Primera victoria",   cond: () => stats.ganadas >= 1 },
  { id: "bj",        nombre: "🃏 ¡Blackjack!",         cond: () => stats.blackjacks >= 1 },
  { id: "racha3",    nombre: "🔥 3 seguidas",          cond: () => stats.mejorRacha >= 3 },
  { id: "racha5",    nombre: "🔥🔥 5 seguidas",        cond: () => stats.mejorRacha >= 5 },
  { id: "banca2k",   nombre: "💰 Banca de $2000",      cond: (banca) => banca >= 2000 },
  { id: "banca5k",   nombre: "💎 Banca de $5000",      cond: (banca) => banca >= 5000 },
  { id: "veterano",  nombre: "🎖️ 50 manos jugadas",    cond: () => stats.jugadas >= 50 },
  { id: "perfecto",  nombre: "🧠 10 manos sin errores", cond: () => config.modoEntrenamiento && stats.jugadas >= 10 && stats.errores === 0 },
];
const logrosDesbloqueados = new Set();

// Revisa qué logros nuevos se ganaron; devuelve la lista de nuevos
function revisarLogros(banca) {
  const nuevos = [];
  for (const l of LOGROS) {
    if (!logrosDesbloqueados.has(l.id) && l.cond(banca)) {
      logrosDesbloqueados.add(l.id);
      nuevos.push(l);
    }
  }
  return nuevos;
}
