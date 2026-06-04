// ============================================================
//  INTERFAZ (UI)
//  Todo lo que dibuja en pantalla: cartas, animaciones, paneles,
//  temas y avisos. No conoce las reglas; solo "pinta".
// ============================================================

const $ = (id) => document.getElementById(id);

// Contenedores de las manos del jugador (para animar carta por carta)
let filasJugador = [];
let infosJugador = [];

// ---------- DIBUJAR CARTAS ----------

// Contenido visual de una carta (esquinas + palo grande en el centro)
function contenidoCara(carta) {
  const rojo = carta.palo === "♥" || carta.palo === "♦";
  return `
    <span class="idx tl ${rojo ? "roja" : ""}">${carta.valor}<br>${carta.palo}</span>
    <span class="suit-centro ${rojo ? "roja" : ""}">${carta.palo}</span>
    <span class="idx br ${rojo ? "roja" : ""}">${carta.valor}<br>${carta.palo}</span>`;
}

// Carta normal, boca arriba (con animación de entrada)
function crearCartaEl(carta) {
  const div = document.createElement("div");
  div.className = "carta";
  div.innerHTML = contenidoCara(carta);
  return div;
}

// Carta oculta del crupier: contenedor con volteo 3D.
// Empieza mostrando el dorso; al revelar gira y muestra la cara.
function crearCartaOcultaEl(carta) {
  const cont = document.createElement("div");
  cont.className = "carta-flip";
  const inner = document.createElement("div");
  inner.className = "carta-inner";
  const dorso = document.createElement("div");
  dorso.className = "cara dorso";
  const frente = document.createElement("div");
  frente.className = "cara frente carta";
  frente.innerHTML = contenidoCara(carta);
  inner.appendChild(dorso);
  inner.appendChild(frente);
  cont.appendChild(inner);
  return cont;
}

// Voltea la carta oculta (animación 3D)
function revelarCartaFlip(cont) {
  if (cont && cont.classList) cont.classList.add("revelada");
}

// ---------- MANOS DEL JUGADOR ----------
function construirGruposJugador(manos, indiceMano) {
  const cont = $("cartas-jugador");
  cont.innerHTML = "";
  filasJugador = [];
  infosJugador = [];
  manos.forEach((mano) => {
    const grupo = document.createElement("div");
    grupo.className = "mano-grupo";
    const fila = document.createElement("div");
    fila.className = "cartas fila-mano";
    mano.cartas.forEach((c) => fila.appendChild(crearCartaEl(c)));
    const info = document.createElement("div");
    info.className = "info-mano";
    grupo.appendChild(fila);
    grupo.appendChild(info);
    cont.appendChild(grupo);
    filasJugador.push(fila);
    infosJugador.push(info);
  });
  refrescarInfos(manos);
  resaltarActiva(manos, indiceMano, true);
}

function refrescarInfos(manos) {
  manos.forEach((mano, i) => {
    if (!infosJugador[i]) return;
    const etiqueta = manos.length > 1 ? `Mano ${i + 1} · ` : "";
    let extra = "";
    if (mano.rendida) extra = " (rendida)";
    else if (mano.doblada) extra = " (doblada)";
    infosJugador[i].textContent = `${etiqueta}$${mano.apuesta} · ${calcularPuntos(mano.cartas)}${extra}`;
  });
}

function resaltarActiva(manos, indiceMano, rondaActiva) {
  filasJugador.forEach((fila, i) => {
    const grupo = fila.parentElement;
    if (!grupo) return;
    grupo.classList.toggle("activa", rondaActiva && manos.length > 1 && i === indiceMano);
  });
}

// ---------- FICHAS QUE VUELAN ----------
function animarFichaVolando(desdeEl) {
  const destino = $("apuesta");
  if (!desdeEl || !destino || !desdeEl.getBoundingClientRect || !document.body) return;
  const r1 = desdeEl.getBoundingClientRect();
  const r2 = destino.getBoundingClientRect();
  const f = document.createElement("div");
  f.className = "ficha-volando";
  f.style.left = r1.left + r1.width / 2 - 16 + "px";
  f.style.top = r1.top + r1.height / 2 - 16 + "px";
  document.body.appendChild(f);
  requestAnimationFrame(() => {
    const dx = r2.left + r2.width / 2 - (r1.left + r1.width / 2);
    const dy = r2.top + r2.height / 2 - (r1.top + r1.height / 2);
    f.style.transform = `translate(${dx}px, ${dy}px) scale(0.4)`;
    f.style.opacity = "0.1";
  });
  setTimeout(() => f.remove(), 550);
}

// ---------- TEMAS ----------
function aplicarTema(nombre) {
  document.body.dataset.tema = nombre;
}

// ---------- PANELES DE INFO ----------
function actualizarInfoShoe() {
  if ($("cartas-restantes")) {
    $("cartas-restantes").textContent = cartasRestantes();
  }
  const cont = $("conteo-caja");
  if (cont) {
    cont.classList.toggle("oculto", !config.mostrarConteo);
    if (config.mostrarConteo) {
      $("conteo-corrido").textContent = conteoCorrido > 0 ? "+" + conteoCorrido : conteoCorrido;
      $("conteo-real").textContent = conteoVerdadero().toFixed(1);
    }
  }
}

function mostrarConsejo(texto) {
  const el = $("consejo");
  if (!el) return;
  el.textContent = texto || "";
  el.classList.toggle("oculto", !texto);
}

function mostrarProbabilidad(texto) {
  const el = $("probabilidad");
  if (!el) return;
  el.textContent = texto || "";
  el.classList.toggle("oculto", !texto);
}

function actualizarPaneles(banca) {
  if ($("st-jugadas")) $("st-jugadas").textContent = stats.jugadas;
  if ($("st-ganadas")) $("st-ganadas").textContent = stats.ganadas;
  if ($("st-perdidas")) $("st-perdidas").textContent = stats.perdidas;
  if ($("st-empates")) $("st-empates").textContent = stats.empates;
  if ($("st-bj")) $("st-bj").textContent = stats.blackjacks;
  if ($("st-winrate")) $("st-winrate").textContent = porcentajeVictorias() + "%";
  if ($("st-racha")) $("st-racha").textContent = stats.rachaActual;
  if ($("st-nivel")) $("st-nivel").textContent = nivelActual().nombre;
  if (config.modoEntrenamiento && $("st-errores-caja")) {
    $("st-errores-caja").classList.remove("oculto");
    $("st-errores").textContent = stats.errores;
  } else if ($("st-errores-caja")) {
    $("st-errores-caja").classList.add("oculto");
  }

  // Historial
  const hist = $("historial-lista");
  if (hist) {
    hist.innerHTML = "";
    historial.forEach((h) => {
      const li = document.createElement("li");
      const signo = h.neto > 0 ? "+" : "";
      li.textContent = `${signo}$${h.neto}`;
      li.className = h.neto > 0 ? "verde" : h.neto < 0 ? "rojo" : "amarillo";
      hist.appendChild(li);
    });
  }

  // Logros
  const lg = $("logros-lista");
  if (lg) {
    lg.innerHTML = "";
    LOGROS.forEach((l) => {
      const li = document.createElement("li");
      const tiene = logrosDesbloqueados.has(l.id);
      li.textContent = (tiene ? "✅ " : "🔒 ") + l.nombre;
      li.className = tiene ? "" : "bloqueado";
      lg.appendChild(li);
    });
  }
}

// ---------- AVISOS (toasts) ----------
function toast(texto, tipo = "info") {
  const cont = $("toasts");
  if (!cont) return;
  const t = document.createElement("div");
  t.className = "toast " + tipo;
  t.textContent = texto;
  cont.appendChild(t);
  setTimeout(() => t.classList.add("visible"), 10);
  setTimeout(() => {
    t.classList.remove("visible");
    setTimeout(() => t.remove(), 300);
  }, 2600);
}

function notificarLogro(logro) {
  toast("Logro desbloqueado: " + logro.nombre, "logro");
}
