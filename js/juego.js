// ============================================================
//  FLUJO PRINCIPAL DEL JUEGO
//  Une todo: estado, reparto carta por carta, turnos, reglas,
//  dinero, estadísticas, conteo, estrategia y probabilidades.
// ============================================================

// ---------- ESTADO ----------
let banca = config.bancaInicial;
let apuesta = 0;
let ultimaApuesta = 0;        // para el botón "Repetir apuesta"
let manos = [];               // { cartas, apuesta, doblada, asPartido, rendida }
let indiceMano = 0;
let manoCrupier = [];
let rondaActiva = false;
let animando = false;
let crupierOculto = true;
let seguro = 0;
let cartaOcultaEl = null;     // referencia al elemento volteable del crupier

const elCartasCrupier = () => $("cartas-crupier");

function esperar(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// ---------- DINERO Y PUNTOS ----------
function actualizarDinero() {
  $("banca").textContent = "$" + banca;
  let enJuego = apuesta;
  if (rondaActiva) {
    enJuego = manos.reduce((s, m) => s + m.apuesta, 0) + seguro;
  }
  $("apuesta").textContent = "$" + enJuego;
  if (banca > stats.mayorBanca) stats.mayorBanca = banca;
}

function actualizarPuntos() {
  if (manos.length && manos[indiceMano]) {
    $("puntos-jugador").textContent = calcularPuntos(manos[indiceMano].cartas);
  } else {
    $("puntos-jugador").textContent = 0;
  }
  if (!manoCrupier.length) {
    $("puntos-crupier").textContent = 0;
  } else {
    $("puntos-crupier").textContent = crupierOculto ? "?" : calcularPuntos(manoCrupier);
  }
}

// ---------- REPARTIR CARTAS (con animación y conteo) ----------
async function darCartaJugador(i, pausa = 420) {
  const carta = sacarCarta();
  manos[i].cartas.push(carta);
  filasJugador[i].appendChild(crearCartaEl(carta));
  contar(carta); // la carta es visible → cuenta para el Hi-Lo
  sonidoCarta();
  refrescarInfos(manos);
  actualizarPuntos();
  actualizarInfoShoe();
  await esperar(pausa);
}

async function darCartaCrupierVisible(pausa = 420) {
  const carta = sacarCarta();
  manoCrupier.push(carta);
  elCartasCrupier().appendChild(crearCartaEl(carta));
  contar(carta);
  sonidoCarta();
  actualizarPuntos();
  actualizarInfoShoe();
  await esperar(pausa);
}

async function darCartaCrupierOculta(pausa = 420) {
  const carta = sacarCarta();
  manoCrupier.push(carta);
  cartaOcultaEl = crearCartaOcultaEl(carta);
  elCartasCrupier().appendChild(cartaOcultaEl);
  // NO se cuenta todavía: está boca abajo
  sonidoCarta();
  actualizarPuntos();
  await esperar(pausa);
}

function revelarCrupier() {
  crupierOculto = false;
  revelarCartaFlip(cartaOcultaEl);
  if (manoCrupier[0]) contar(manoCrupier[0]); // ahora sí cuenta la carta oculta
  actualizarPuntos();
  actualizarInfoShoe();
}

// ---------- OPCIONES Y BOTONES ----------
function puedeDividir(mano) {
  if (!mano || mano.cartas.length !== 2) return false;
  if (mano.asPartido) return false;
  if (manos.length >= 4) return false; // límite de manos
  if (banca < mano.apuesta) return false;
  return mismoValorSplit(mano.cartas[0], mano.cartas[1]);
}

function opcionesActuales(mano) {
  return {
    puedeDoblar: !!mano && mano.cartas.length === 2 && !mano.doblada && banca >= mano.apuesta,
    puedeDividir: puedeDividir(mano),
    puedeRendirse: config.permitirRendirse && !!mano && mano.cartas.length === 2 && manos.length === 1,
  };
}

function actualizarBotones() {
  const libre = rondaActiva && !animando;
  const mano = manos[indiceMano];
  const opc = mano ? opcionesActuales(mano) : {};

  $("btn-pedir").disabled = !libre;
  $("btn-plantarse").disabled = !libre;

  const pDoblar = libre && opc.puedeDoblar;
  $("btn-doblar").disabled = !pDoblar;
  $("btn-doblar").classList.toggle("disponible", pDoblar);

  const pDividir = libre && opc.puedeDividir;
  $("btn-dividir").disabled = !pDividir;
  $("btn-dividir").classList.toggle("disponible", pDividir);

  const pRendir = libre && opc.puedeRendirse;
  $("btn-rendirse").disabled = !pRendir;
  $("btn-rendirse").classList.toggle("oculto", !config.permitirRendirse);
}

// ---------- AYUDAS: consejo y probabilidad ----------
function actualizarAyudas() {
  const mano = manos[indiceMano];
  if (!mano || !rondaActiva) {
    mostrarConsejo("");
    mostrarProbabilidad("");
    return;
  }
  // Consejo de estrategia básica
  const rec = consejoEstrategia(mano.cartas, manoCrupier[1], opcionesActuales(mano));
  mostrarConsejo("💡 Estrategia óptima: " + nombreJugada(rec));

  // Probabilidad de pasarse
  if (config.mostrarProbabilidad) {
    const p = probabilidadPasarse(mano.cartas);
    mostrarProbabilidad(`Si pides: ${Math.round(p * 100)}% de pasarte`);
  } else {
    mostrarProbabilidad("");
  }
}

// En modo entrenamiento, avisa si la jugada no fue la óptima
function chequearEntrenamiento(jugada) {
  if (!config.modoEntrenamiento) return;
  const mano = manos[indiceMano];
  if (!mano) return;
  const rec = consejoEstrategia(mano.cartas, manoCrupier[1], opcionesActuales(mano));
  if (rec !== jugada) {
    stats.errores++;
    toast(`❌ Lo óptimo era ${nombreJugada(rec)}, no ${nombreJugada(jugada)}`, "aviso");
  }
}

// ---------- FASE DE APUESTAS ----------
function clamp(v) {
  return Math.max(0, Math.min(v, banca, config.apuestaMax));
}

function sumarFicha(valor, botonEl) {
  if (rondaActiva || animando) return;
  if (apuesta + valor > banca) { toast("No te alcanza la banca", "aviso"); return; }
  if (apuesta + valor > config.apuestaMax) { toast("Apuesta máxima: $" + config.apuestaMax, "aviso"); return; }
  apuesta += valor;
  sonidoFicha();
  animarFichaVolando(botonEl);
  actualizarDinero();
  $("mensaje").textContent = `Apuesta: $${apuesta} (mín $${config.apuestaMin} · máx $${config.apuestaMax}).`;
}

function limpiarApuesta() {
  if (rondaActiva || animando) return;
  apuesta = 0;
  actualizarDinero();
  $("mensaje").textContent = "Apuesta reiniciada.";
}

function repetirApuesta() {
  if (rondaActiva || animando) return;
  apuesta = clamp(ultimaApuesta || config.apuestaMin);
  sonidoFicha();
  actualizarDinero();
  $("mensaje").textContent = "Apuesta repetida: $" + apuesta;
}

function doblarApuestaPendiente() {
  if (rondaActiva || animando) return;
  apuesta = clamp((apuesta || config.apuestaMin) * 2);
  sonidoFicha();
  actualizarDinero();
  $("mensaje").textContent = "Apuesta: $" + apuesta;
}

// ---------- REPARTIR ----------
async function repartir() {
  if (animando) return;
  if (apuesta < config.apuestaMin) { toast("Apuesta mínima: $" + config.apuestaMin, "aviso"); return; }
  if (apuesta > banca) { toast("No te alcanza la banca", "aviso"); return; }

  // ¿Hace falta barajar? (penetración del shoe)
  if (shoe.length === 0 || necesitaBarajar()) {
    crearShoe();
    sonidoBarajar();
    toast("Barajando " + config.numBarajas + " barajas...", "info");
  }

  ultimaApuesta = apuesta;
  banca -= apuesta;
  actualizarDinero();

  manos = [{ cartas: [], apuesta: apuesta, doblada: false, asPartido: false, rendida: false }];
  indiceMano = 0;
  manoCrupier = [];
  elCartasCrupier().innerHTML = "";
  cartaOcultaEl = null;
  rondaActiva = true;
  seguro = 0;
  crupierOculto = true;
  animando = true;
  construirGruposJugador(manos, indiceMano);

  $("zona-apuesta").classList.add("oculto");
  $("zona-juego").classList.add("oculto");
  $("zona-nueva").classList.add("oculto");
  $("zona-seguro").classList.add("oculto");
  $("zona-prestamo").classList.add("oculto");
  $("resultado-dinero").textContent = "—";
  $("resultado-dinero").className = "valor";
  $("mensaje").textContent = "Repartiendo...";
  mostrarConsejo(""); mostrarProbabilidad("");

  await darCartaJugador(0);
  await darCartaCrupierOculta();
  await darCartaJugador(0);
  await darCartaCrupierVisible();

  animando = false;

  // Seguro si el crupier muestra un As
  const crupierMuestraAs = manoCrupier[1].valor === "A";
  if (crupierMuestraAs && banca >= Math.floor(apuesta / 2)) {
    $("zona-seguro").classList.remove("oculto");
    $("mensaje").textContent = "El crupier muestra un As. ¿Seguro?";
  } else {
    await iniciarTurnoJugador();
  }
}

async function tomarSeguro(quiere) {
  $("zona-seguro").classList.add("oculto");
  if (quiere) {
    seguro = Math.floor(apuesta / 2);
    banca -= seguro;
    actualizarDinero();
    $("mensaje").textContent = "Seguro tomado por $" + seguro + ".";
  }
  await iniciarTurnoJugador();
}

// ---------- INICIO DEL TURNO ----------
async function iniciarTurnoJugador() {
  if (calcularPuntos(manoCrupier) === 21) {
    revelarCrupier();
    await esperar(600);
    finalizarRonda();
    return;
  }
  if (calcularPuntos(manos[0].cartas) === 21) {
    revelarCrupier();
    await esperar(600);
    finalizarRonda();
    return;
  }
  await jugarManoActiva();
}

async function jugarManoActiva() {
  animando = true;
  $("zona-juego").classList.add("oculto");
  actualizarBotones();
  resaltarActiva(manos, indiceMano, true);

  const mano = manos[indiceMano];
  if (mano.cartas.length < 2) {
    await darCartaJugador(indiceMano, 420);
  }

  if (mano.asPartido) {
    $("mensaje").textContent = `As dividido (mano ${indiceMano + 1}): una sola carta.`;
    await esperar(700);
    await avanzarMano();
    return;
  }

  if (calcularPuntos(mano.cartas) === 21) {
    await esperar(400);
    await avanzarMano();
    return;
  }

  // Turno normal
  animando = false;
  $("zona-juego").classList.remove("oculto");
  let texto = manos.length > 1 ? `Juega la mano ${indiceMano + 1}.` : "Tu turno.";
  if (puedeDividir(mano)) texto += " ¡Par! Puedes DIVIDIR 🟢";
  $("mensaje").textContent = texto;
  actualizarBotones();
  actualizarAyudas();
}

async function avanzarMano() {
  if (indiceMano < manos.length - 1) {
    indiceMano++;
    actualizarPuntos();
    await jugarManoActiva();
  } else {
    await jugarCrupier();
  }
}

// ---------- ACCIONES ----------
async function pedirCarta() {
  if (!rondaActiva || animando) return;
  chequearEntrenamiento("pedir");
  animando = true;
  actualizarBotones();
  mostrarConsejo(""); mostrarProbabilidad("");

  await darCartaJugador(indiceMano, 420);
  const puntos = calcularPuntos(manos[indiceMano].cartas);

  if (puntos > 21) {
    const etq = manos.length > 1 ? `Mano ${indiceMano + 1}: ` : "";
    $("mensaje").textContent = `${etq}te pasaste con ${puntos}.`;
    await esperar(700);
    await avanzarMano();
  } else if (puntos === 21) {
    await avanzarMano();
  } else {
    animando = false;
    actualizarBotones();
    actualizarAyudas();
  }
}

async function doblar() {
  if (!rondaActiva || animando) return;
  const mano = manos[indiceMano];
  if (mano.cartas.length !== 2 || mano.doblada || banca < mano.apuesta) return;
  chequearEntrenamiento("doblar");
  animando = true;
  actualizarBotones();
  mostrarConsejo(""); mostrarProbabilidad("");

  banca -= mano.apuesta;
  mano.apuesta *= 2;
  mano.doblada = true;
  actualizarDinero();
  refrescarInfos(manos);
  $("mensaje").textContent = "¡Doblaste! Una sola carta.";

  await darCartaJugador(indiceMano, 600);
  const puntos = calcularPuntos(mano.cartas);
  if (puntos > 21) {
    $("mensaje").textContent = `Doblaste y te pasaste con ${puntos}.`;
    await esperar(700);
  }
  await avanzarMano();
}

async function dividir() {
  if (!rondaActiva || animando) return;
  const mano = manos[indiceMano];
  if (!puedeDividir(mano)) return;
  chequearEntrenamiento("dividir");
  animando = true;
  actualizarBotones();
  mostrarConsejo(""); mostrarProbabilidad("");

  banca -= mano.apuesta;
  actualizarDinero();

  const cartaMovida = mano.cartas.pop();
  const esAs = cartaMovida.valor === "A";
  const nueva = { cartas: [cartaMovida], apuesta: mano.apuesta, doblada: false, asPartido: esAs, rendida: false };
  mano.asPartido = esAs;
  manos.splice(indiceMano + 1, 0, nueva);

  construirGruposJugador(manos, indiceMano);
  $("mensaje").textContent = "Dividiste tu mano en dos.";
  await esperar(500);
  await jugarManoActiva();
}

async function rendirse() {
  if (!rondaActiva || animando) return;
  const mano = manos[indiceMano];
  const opc = opcionesActuales(mano);
  if (!opc.puedeRendirse) return;
  chequearEntrenamiento("rendirse");
  animando = true;
  actualizarBotones();
  mostrarConsejo(""); mostrarProbabilidad("");

  mano.rendida = true;
  refrescarInfos(manos);
  sonidoRendirse();
  $("mensaje").textContent = "Te rendiste: recuperas la mitad de la apuesta.";
  await esperar(600);
  await avanzarMano();
}

async function plantarse() {
  if (!rondaActiva || animando) return;
  chequearEntrenamiento("plantarse");
  animando = true;
  actualizarBotones();
  mostrarConsejo(""); mostrarProbabilidad("");
  await avanzarMano();
}

// ---------- TURNO DEL CRUPIER ----------
async function jugarCrupier() {
  animando = true;
  $("zona-juego").classList.add("oculto");
  resaltarActiva(manos, indiceMano, false);
  mostrarConsejo(""); mostrarProbabilidad("");

  revelarCrupier();
  await esperar(700);

  // Solo juega si alguna mano sigue viva (no pasada y no rendida)
  const algunaViva = manos.some((m) => !m.rendida && calcularPuntos(m.cartas) <= 21);
  if (algunaViva) {
    while (debePedirCrupier()) {
      $("mensaje").textContent = "El crupier pide carta...";
      await darCartaCrupierVisible(700);
    }
  }
  finalizarRonda();
}

// Regla del crupier: pide con 16 o menos; con 17 suave pide solo si H17 está activo
function debePedirCrupier() {
  const { total, suave } = infoMano(manoCrupier);
  if (total < 17) return true;
  if (total === 17 && suave && config.crupierPideEn17Suave) return true;
  return false;
}

// ---------- RESOLVER ----------
function resolverMano(mano) {
  const pj = calcularPuntos(mano.cartas);
  let pc = calcularPuntos(manoCrupier);

  // Rendición: pierde la mitad
  if (mano.rendida) {
    return { estado: "rendir", ganancia: Math.floor(mano.apuesta / 2), esBlackjack: false };
  }

  const esBlackjack = manos.length === 1 && mano.cartas.length === 2 && pj === 21 && !mano.doblada;

  let estado;
  if (pj > 21) {
    estado = "perder";
  } else if (config.empujeEn22 && pc === 22) {
    estado = "empate"; // variante: crupier 22 empuja
  } else if (pc > 21) {
    estado = "ganar";
  } else if (pj > pc) {
    estado = "ganar";
  } else if (pj < pc) {
    estado = "perder";
  } else {
    estado = "empate";
  }

  let ganancia = 0;
  if (estado === "ganar") {
    ganancia = esBlackjack
      ? mano.apuesta + Math.floor(mano.apuesta * config.pagoBlackjack)
      : mano.apuesta * 2;
  } else if (estado === "empate") {
    ganancia = mano.apuesta;
  }
  return { estado, ganancia, esBlackjack };
}

function finalizarRonda() {
  rondaActiva = false;
  animando = false;

  let netoTotal = 0;
  let huboBlackjack = false;
  const partes = [];

  // Seguro
  if (seguro > 0) {
    const crupierBlackjack = manoCrupier.length === 2 && calcularPuntos(manoCrupier) === 21;
    if (crupierBlackjack) {
      banca += seguro * 3;
      netoTotal += seguro * 2;
      partes.push(`Seguro +$${seguro * 2}`);
    } else {
      netoTotal -= seguro;
      partes.push(`Seguro -$${seguro}`);
    }
  }

  // Cada mano
  manos.forEach((mano, i) => {
    const r = resolverMano(mano);
    banca += r.ganancia;
    const neto = r.ganancia - mano.apuesta;
    netoTotal += neto;
    registrarResultado(r.estado === "rendir" ? "perder" : r.estado, r.esBlackjack);
    if (r.esBlackjack && r.estado === "ganar") huboBlackjack = true;

    const etq = manos.length > 1 ? `Mano ${i + 1}: ` : "";
    if (r.estado === "ganar") partes.push(r.esBlackjack ? `${etq}¡BLACKJACK! +$${neto}` : `${etq}ganas +$${neto}`);
    else if (r.estado === "empate") partes.push(`${etq}empate`);
    else if (r.estado === "rendir") partes.push(`${etq}rendido -$${mano.apuesta - r.ganancia}`);
    else partes.push(`${etq}pierdes -$${mano.apuesta}`);
  });

  const pc = calcularPuntos(manoCrupier);
  const textoCrupier = pc > 21 ? `se pasó (${pc})` : pc;
  $("mensaje").textContent = `Crupier: ${textoCrupier}. ` + partes.join(" · ");

  if (netoTotal > 0) {
    $("resultado-dinero").textContent = "+$" + netoTotal;
    $("resultado-dinero").className = "valor verde";
    huboBlackjack ? sonidoBlackjack() : sonidoGanar();
  } else if (netoTotal < 0) {
    $("resultado-dinero").textContent = "-$" + Math.abs(netoTotal);
    $("resultado-dinero").className = "valor rojo";
    sonidoPerder();
  } else {
    $("resultado-dinero").textContent = "$0";
    $("resultado-dinero").className = "valor amarillo";
    sonidoEmpate();
  }

  registrarHistorial(netoTotal);
  apuesta = 0;
  seguro = 0;
  actualizarDinero();
  resaltarActiva(manos, indiceMano, false);
  actualizarInfoShoe();
  actualizarPaneles(banca);

  // Logros nuevos
  const nuevos = revisarLogros(banca);
  nuevos.forEach((l) => { notificarLogro(l); sonidoLogro(); });

  $("zona-juego").classList.add("oculto");
  $("zona-seguro").classList.add("oculto");

  if (banca <= 0) {
    $("mensaje").textContent = "Te quedaste sin dinero. Pide un préstamo para seguir.";
    $("zona-nueva").classList.add("oculto");
    $("zona-prestamo").classList.remove("oculto");
  } else {
    $("zona-nueva").classList.remove("oculto");
  }
}

// ---------- NUEVA RONDA / PRÉSTAMO ----------
function nuevaRonda() {
  if (animando) return;
  manos = [];
  indiceMano = 0;
  manoCrupier = [];
  $("cartas-jugador").innerHTML = "";
  elCartasCrupier().innerHTML = "";
  $("puntos-jugador").textContent = "0";
  $("puntos-crupier").textContent = "0";
  $("zona-nueva").classList.add("oculto");
  $("zona-seguro").classList.add("oculto");
  $("zona-juego").classList.add("oculto");
  $("zona-apuesta").classList.remove("oculto");
  mostrarConsejo(""); mostrarProbabilidad("");
  $("mensaje").textContent = "Elige tu apuesta para la siguiente mano.";
}

function pedirPrestamo() {
  banca += 500;
  stats.prestamos++;
  sonidoMoneda();
  actualizarDinero();
  $("zona-prestamo").classList.add("oculto");
  toast("Préstamo de $500 (préstamos: " + stats.prestamos + ")", "info");
  nuevaRonda();
}

// ---------- ARRANQUE ----------
function iniciarJuego() {
  crearShoe();
  actualizarDinero();
  actualizarInfoShoe();
  actualizarPaneles(banca);
  aplicarTema("verde");
}
