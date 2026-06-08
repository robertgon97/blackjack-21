// ============================================================
//  ESTRATEGIA BÁSICA DE BLACKJACK
//  Tablas matemáticamente óptimas (multi-baraja, el crupier se
//  planta en 17 suave). Devuelve la jugada recomendada para
//  enseñarte a jugar bien y para el "modo entrenamiento".
//
//  Códigos internos:
//   H  = pedir            S  = plantarse
//   D  = doblar (si no se puede, pedir)
//   Ds = doblar (si no se puede, plantarse)
//   P  = dividir          R  = rendirse (si no se puede, pedir)
// ============================================================

// Valor de la carta del crupier (As = 11)
function valorCarta(carta) {
  if (carta.valor === "A") return 11;
  if (["J", "Q", "K", "10"].includes(carta.valor)) return 10;
  return Number(carta.valor);
}

// Recomienda una jugada. opc = { puedeDoblar, puedeDividir, puedeRendirse }
function consejoEstrategia(cartas, cartaCrupier, opc) {
  const up = valorCarta(cartaCrupier); // 2..11
  const { total, suave } = infoMano(cartas);

  // 1) PAREJAS (solo con 2 cartas del mismo valor)
  if (cartas.length === 2 && mismoValorSplit(cartas[0], cartas[1])) {
    const codigo = consejoPareja(valorSplit(cartas[0]), up);
    if (codigo === "P") return traducir("P", opc, total, suave);
    // si la tabla dice que NO se divide, seguimos con total duro/blando
  }

  // 2) RENDIRSE (late surrender, solo con 2 cartas)
  if (opc.puedeRendirse && cartas.length === 2 && !suave) {
    if (total === 16 && (up === 9 || up === 10 || up === 11)) return traducir("R", opc, total, suave);
    if (total === 15 && up === 10) return traducir("R", opc, total, suave);
  }

  // 3) MANO BLANDA (con As de 11)
  if (suave) return traducir(consejoBlanda(total, up), opc, total, suave);

  // 4) MANO DURA
  return traducir(consejoDura(total, up), opc, total, suave);
}

// ---- Tabla de PAREJAS ----
function consejoPareja(valor, up) {
  switch (valor) {
    case "A": return "P";                       // Ases: siempre dividir
    case "10": return "S";                      // 10/figuras: nunca dividir
    case "9": return [7, 10, 11].includes(up) ? "S" : "P"; // se planta vs 7,10,A
    case "8": return "P";                       // Ochos: siempre dividir
    case "7": return up <= 7 ? "P" : "H";
    case "6": return up <= 6 ? "P" : "H";
    case "5": return up <= 9 ? "D" : "H";       // como un 10 duro
    case "4": return up === 5 || up === 6 ? "P" : "H";
    case "3":
    case "2": return up <= 7 ? "P" : "H";
    default: return "H";
  }
}

// ---- Tabla de manos BLANDAS (total incluye el As como 11) ----
function consejoBlanda(total, up) {
  switch (total) {
    case 20: return "S";              // A,9
    case 19: return up === 6 ? "Ds" : "S"; // A,8
    case 18: // A,7
      if (up >= 3 && up <= 6) return "Ds";
      if (up === 2 || up === 7 || up === 8) return "S";
      return "H"; // vs 9,10,A
    case 17: return up >= 3 && up <= 6 ? "D" : "H"; // A,6
    case 16:
    case 15: return up >= 4 && up <= 6 ? "D" : "H"; // A,5 / A,4
    case 14:
    case 13: return up === 5 || up === 6 ? "D" : "H"; // A,3 / A,2
    default: return "S";
  }
}

// ---- Tabla de manos DURAS ----
function consejoDura(total, up) {
  if (total >= 17) return "S";
  if (total >= 13 && total <= 16) return up <= 6 ? "S" : "H";
  if (total === 12) return up >= 4 && up <= 6 ? "S" : "H";
  if (total === 11) return "D";
  if (total === 10) return up <= 9 ? "D" : "H";
  if (total === 9) return up >= 3 && up <= 6 ? "D" : "H";
  return "H"; // 5-8
}

// Convierte el código en una jugada real según lo que esté permitido
function traducir(codigo, opc, total, suave) {
  switch (codigo) {
    case "P": return opc.puedeDividir ? "dividir" : (suave ? "pedir" : (total >= 17 ? "plantarse" : "pedir"));
    case "D": return opc.puedeDoblar ? "doblar" : "pedir";
    case "Ds": return opc.puedeDoblar ? "doblar" : "plantarse";
    case "R": return opc.puedeRendirse ? "rendirse" : "pedir";
    case "S": return "plantarse";
    case "H": return "pedir";
    default: return "pedir";
  }
}

// Texto bonito para mostrar al usuario
function nombreJugada(jugada) {
  return {
    pedir: "PEDIR carta",
    plantarse: "PLANTARSE",
    doblar: "DOBLAR",
    dividir: "DIVIDIR",
    rendirse: "RENDIRSE",
  }[jugada] || jugada;
}
