// ============================================================
//  CARTAS, MAZO MÚLTIPLE (SHOE) Y CONTEO
//  Aquí vive todo lo relacionado con las cartas: crear el shoe,
//  barajar, repartir, calcular puntos, conteo Hi-Lo y
//  probabilidades. NO toca el DOM (eso es trabajo de ui.js).
// ============================================================

const PALOS = ["♠", "♥", "♦", "♣"];
const VALORES = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"];

let shoe = [];          // El "zapato": varias barajas mezcladas
let totalShoe = 0;      // Cuántas cartas tenía el shoe recién barajado
let conteoCorrido = 0;  // Conteo Hi-Lo "corrido" (running count)

// Crea el shoe con N barajas y lo baraja
function crearShoe() {
  shoe = [];
  for (let b = 0; b < config.numBarajas; b++) {
    for (const palo of PALOS) {
      for (const valor of VALORES) {
        shoe.push({ palo, valor });
      }
    }
  }
  barajar(shoe);
  totalShoe = shoe.length;
  conteoCorrido = 0;
}

// Algoritmo Fisher-Yates (mezcla justa)
function barajar(m) {
  for (let i = m.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [m[i], m[j]] = [m[j], m[i]];
  }
  return m;
}

// ¿Conviene volver a barajar? (penetración del 25%, como en casinos)
function necesitaBarajar() {
  return shoe.length < totalShoe * 0.25;
}

// Saca la carta de arriba del shoe (si se acaba, crea uno nuevo)
function sacarCarta() {
  if (shoe.length === 0) crearShoe();
  return shoe.pop();
}

function cartasRestantes() {
  return shoe.length;
}

function barajasRestantes() {
  return shoe.length / 52;
}

// ============================================================
//  PUNTOS
//  El As vale 11, pero baja a 1 si te ayuda a no pasarte de 21.
// ============================================================
function calcularPuntos(cartas) {
  let total = 0;
  let ases = 0;
  for (const carta of cartas) {
    if (carta.valor === "A") {
      ases++;
      total += 11;
    } else if (["J", "Q", "K"].includes(carta.valor)) {
      total += 10;
    } else {
      total += Number(carta.valor);
    }
  }
  while (total > 21 && ases > 0) {
    total -= 10;
    ases--;
  }
  return total;
}

// Devuelve { total, suave } — "suave" = tiene un As contando como 11
function infoMano(cartas) {
  let total = 0;
  let ases = 0;
  for (const carta of cartas) {
    if (carta.valor === "A") {
      ases++;
      total += 11;
    } else if (["J", "Q", "K"].includes(carta.valor)) {
      total += 10;
    } else {
      total += Number(carta.valor);
    }
  }
  while (total > 21 && ases > 0) {
    total -= 10;
    ases--;
  }
  return { total, suave: ases > 0 };
}

// Valor a efectos de división: las figuras y el 10 cuentan igual ("10")
function valorSplit(carta) {
  if (carta.valor === "A") return "A";
  if (["10", "J", "Q", "K"].includes(carta.valor)) return "10";
  return carta.valor;
}
function mismoValorSplit(a, b) {
  return valorSplit(a) === valorSplit(b);
}

// ============================================================
//  CONTEO DE CARTAS Hi-Lo
//  2-6 suman +1, 7-9 valen 0, 10/figuras/As restan -1.
//  Se cuenta cada carta cuando se hace VISIBLE.
// ============================================================
function valorConteo(carta) {
  if (["2", "3", "4", "5", "6"].includes(carta.valor)) return 1;
  if (["7", "8", "9"].includes(carta.valor)) return 0;
  return -1; // 10, J, Q, K, A
}

function contar(carta) {
  conteoCorrido += valorConteo(carta);
}

// Conteo "verdadero" = corrido / barajas restantes (ajusta por tamaño del shoe)
function conteoVerdadero() {
  const baraj = barajasRestantes();
  if (baraj < 0.1) return conteoCorrido;
  return conteoCorrido / baraj;
}

// ============================================================
//  PROBABILIDAD DE PASARSE si pides otra carta
//  Mira las cartas que quedan en el shoe y cuenta cuántas te
//  harían superar 21.
// ============================================================
function probabilidadPasarse(cartas) {
  const total = calcularPuntos(cartas);
  if (total >= 21) return total > 21 ? 1 : 0;
  if (shoe.length === 0) return 0;
  let pasan = 0;
  for (const c of shoe) {
    if (calcularPuntos([...cartas, c]) > 21) pasan++;
  }
  return pasan / shoe.length;
}
