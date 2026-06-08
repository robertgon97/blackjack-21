// ============================================================
//  ARRANQUE Y CONEXIÓN DE LA INTERFAZ
//  Une los botones del HTML con las funciones del juego.
// ============================================================

// ---- Fichas ----
document.querySelectorAll(".ficha").forEach((btn) => {
  btn.addEventListener("click", () => sumarFicha(Number(btn.dataset.valor), btn));
});

// ---- Apuestas ----
$("btn-limpiar").addEventListener("click", limpiarApuesta);
$("btn-repetir").addEventListener("click", repetirApuesta);
$("btn-doblar-apuesta").addEventListener("click", doblarApuestaPendiente);
$("btn-repartir").addEventListener("click", repartir);

// ---- Acciones de juego ----
$("btn-pedir").addEventListener("click", pedirCarta);
$("btn-plantarse").addEventListener("click", plantarse);
$("btn-doblar").addEventListener("click", doblar);
$("btn-dividir").addEventListener("click", dividir);
$("btn-rendirse").addEventListener("click", rendirse);

// ---- Seguro / nueva ronda / préstamo ----
$("btn-seguro-si").addEventListener("click", () => tomarSeguro(true));
$("btn-seguro-no").addEventListener("click", () => tomarSeguro(false));
$("btn-nueva").addEventListener("click", nuevaRonda);
$("btn-prestamo").addEventListener("click", pedirPrestamo);

// ---- Sonido ----
$("btn-sonido").addEventListener("click", () => {
  silencio = !silencio;
  $("btn-sonido").textContent = silencio ? "🔇" : "🔊";
  if (!silencio) sonidoFicha();
});

// ---- Ambiente de fondo ----
$("btn-ambiente").addEventListener("click", () => {
  alternarAmbiente(!ambienteActivo);
  $("btn-ambiente").classList.toggle("activo", ambienteActivo);
});

// ---- Temas (desplegable personalizado) ----
const TEMAS = {
  verde: { icono: "🟢", nombre: "Clásico" },
  azul: { icono: "🔵", nombre: "Noche" },
  rojo: { icono: "🔴", nombre: "Rubí" },
  oscuro: { icono: "⚫", nombre: "Oscuro" },
};
const ddTema = $("dd-tema");
const ddMenu = $("dd-tema-menu");

function abrirMenuTema() { ddMenu.classList.remove("oculto"); ddTema.classList.add("abierto"); }
function cerrarMenuTema() { ddMenu.classList.add("oculto"); ddTema.classList.remove("abierto"); }

function seleccionarTema(valor) {
  aplicarTema(valor);
  $("dd-tema-icono").textContent = TEMAS[valor].icono;
  $("dd-tema-label").textContent = TEMAS[valor].nombre;
  ddMenu.querySelectorAll("li").forEach((li) => li.classList.toggle("activo", li.dataset.valor === valor));
  cerrarMenuTema();
}

$("dd-tema-toggle").addEventListener("click", (e) => {
  e.stopPropagation();
  ddMenu.classList.contains("oculto") ? abrirMenuTema() : cerrarMenuTema();
});
ddMenu.querySelectorAll("li").forEach((li) => {
  li.addEventListener("click", () => seleccionarTema(li.dataset.valor));
});
// Cerrar el menú al hacer clic fuera
document.addEventListener("click", (e) => { if (!ddTema.contains(e.target)) cerrarMenuTema(); });
// Estado inicial del selector
seleccionarTema("verde");

// ============================================================
//  PANEL DE AJUSTES (reglas)
// ============================================================
function abrirAjustes() {
  // Cargar los valores actuales en el formulario
  $("aj-barajas").value = config.numBarajas;
  $("aj-pago").value = String(config.pagoBlackjack);
  $("aj-min").value = config.apuestaMin;
  $("aj-max").value = config.apuestaMax;
  $("aj-h17").checked = config.crupierPideEn17Suave;
  $("aj-empuje22").checked = config.empujeEn22;
  $("aj-rendirse").checked = config.permitirRendirse;
  $("aj-entrenamiento").checked = config.modoEntrenamiento;
  $("aj-conteo").checked = config.mostrarConteo;
  $("aj-probabilidad").checked = config.mostrarProbabilidad;
  $("modal-ajustes").classList.remove("oculto");
}

function guardarAjustes() {
  config.numBarajas = Math.max(1, Math.min(8, Number($("aj-barajas").value) || 6));
  config.pagoBlackjack = Number($("aj-pago").value);
  config.apuestaMin = Math.max(1, Number($("aj-min").value) || 10);
  config.apuestaMax = Math.max(config.apuestaMin, Number($("aj-max").value) || 500);
  config.crupierPideEn17Suave = $("aj-h17").checked;
  config.empujeEn22 = $("aj-empuje22").checked;
  config.permitirRendirse = $("aj-rendirse").checked;
  config.modoEntrenamiento = $("aj-entrenamiento").checked;
  config.mostrarConteo = $("aj-conteo").checked;
  config.mostrarProbabilidad = $("aj-probabilidad").checked;

  // Aplicar cambios que requieren rebarajar
  crearShoe();
  actualizarInfoShoe();
  actualizarPaneles(banca);
  actualizarBotones();
  $("modal-ajustes").classList.add("oculto");
  toast("Reglas guardadas", "info");
}

$("btn-ajustes").addEventListener("click", abrirAjustes);
$("btn-guardar-ajustes").addEventListener("click", guardarAjustes);
$("btn-cerrar-ajustes").addEventListener("click", () => $("modal-ajustes").classList.add("oculto"));

// ============================================================
//  TUTORIAL INTERACTIVO
// ============================================================
const PASOS_TUTORIAL = [
  "👋 ¡Bienvenido! El objetivo es acercarte a 21 sin pasarte, y superar al crupier.",
  "💰 Primero apuestas con las fichas. Ese dinero sale de tu Banca.",
  "🃏 Recibes 2 cartas. El crupier muestra una y oculta la otra. Las figuras valen 10; el As vale 11 o 1.",
  "🎯 'Pedir' suma otra carta. 'Plantarse' termina tu turno. Si pasas de 21, pierdes.",
  "⚡ 'Doblar' duplica la apuesta y recibes 1 sola carta. 'Dividir' separa un par en dos manos.",
  "🛡️ 'Rendirse' abandona la mano y recupera la mitad. 'Seguro' aparece si el crupier muestra un As.",
  "💡 El consejo de estrategia te dice la jugada óptima. Activa el 'Modo entrenamiento' en Ajustes para practicar.",
  "🏆 Gana manos para subir de nivel y desbloquear logros. ¡Suerte!",
];
let pasoTutorial = 0;

function mostrarTutorial() {
  pasoTutorial = 0;
  $("modal-tutorial").classList.remove("oculto");
  pintarPasoTutorial();
}
function pintarPasoTutorial() {
  $("tutorial-texto").textContent = PASOS_TUTORIAL[pasoTutorial];
  $("tutorial-progreso").textContent = `${pasoTutorial + 1} / ${PASOS_TUTORIAL.length}`;
  $("btn-tutorial-ant").disabled = pasoTutorial === 0;
  $("btn-tutorial-sig").textContent = pasoTutorial === PASOS_TUTORIAL.length - 1 ? "Cerrar" : "Siguiente";
}
$("btn-tutorial").addEventListener("click", mostrarTutorial);
$("btn-tutorial-ant").addEventListener("click", () => { if (pasoTutorial > 0) { pasoTutorial--; pintarPasoTutorial(); } });
$("btn-tutorial-sig").addEventListener("click", () => {
  if (pasoTutorial === PASOS_TUTORIAL.length - 1) { $("modal-tutorial").classList.add("oculto"); }
  else { pasoTutorial++; pintarPasoTutorial(); }
});

// ============================================================
//  INICIO
// ============================================================
iniciarJuego();
