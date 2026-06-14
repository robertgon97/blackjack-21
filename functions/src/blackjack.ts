// ─────────────────────────────────────────────────────────────────────────────
// Lógica pura de Blackjack en TypeScript — espejo de
// lib/features/game/domain/cartas.dart · reglas.dart
//
// Compartida por las Cloud Functions server-side (playerAction, resolveSoloRound)
// para resolver/validar manos sin confiar en el cliente. Al cambiar la lógica de
// puntuación o resolución en Dart, actualizar también aquí (la duplicación
// TS ≠ Dart es inevitable, pero centralizarla en un módulo evita divergencias
// entre funciones).
// ─────────────────────────────────────────────────────────────────────────────

export interface Carta {
  palo?: string;
  valor: string;
}

export interface Mano {
  cartas: Carta[];
  apuesta: number;
  doblada?: boolean;
  rendida: boolean;
  asPartido?: boolean;
}

/** Total óptimo de una mano (los ases bajan de 11 a 1 para no pasarse). */
export function calcularPuntos(cartas: Carta[]): number {
  let total = 0;
  let ases = 0;
  for (const carta of cartas) {
    if (carta.valor === 'A') {
      total += 11;
      ases++;
    } else if (['J', 'Q', 'K'].includes(carta.valor)) {
      total += 10;
    } else {
      total += parseInt(carta.valor, 10);
    }
  }
  while (total > 21 && ases > 0) {
    total -= 10;
    ases--;
  }
  return total;
}

/**
 * Espejo de infoMano (cartas.dart): total óptimo y si la mano es "suave"
 * (queda al menos un As contando como 11 tras reducir para no pasarse).
 */
export function infoMano(cartas: Carta[]): { total: number; suave: boolean } {
  let total = 0;
  let ases = 0;
  for (const c of cartas) {
    if (c.valor === 'A') {
      total += 11;
      ases++;
    } else if (['J', 'Q', 'K'].includes(c.valor)) {
      total += 10;
    } else {
      total += parseInt(c.valor, 10);
    }
  }
  while (total > 21 && ases > 0) {
    total -= 10;
    ases--;
  }
  return { total, suave: ases > 0 };
}

/** ¿El crupier debe pedir carta? Con H17 pide también en 17 suave. */
export function debePedirCrupier(cartas: Carta[], h17: boolean): boolean {
  const { total, suave } = infoMano(cartas);
  if (total < 17) return true;
  // Con H17 el crupier pide en 17 suave (incluye manos multi-as como A+A+5).
  if (total === 17 && suave && h17) return true;
  return false;
}

/**
 * Resuelve una mano del jugador contra la del crupier.
 * Devuelve el `result` (win/lose/push/blackjack/surrender) y el `delta` neto
 * respecto a la apuesta (positivo gana, negativo pierde).
 */
export function resolverMano(
  mano: Mano,
  dealerCards: Carta[],
  esUnica: boolean,
  config: Record<string, unknown>,
): { result: string; delta: number } {
  const pagoBlackjack = (config['pagoBlackjack'] as number) || 1.5;
  const empujeEn22 = (config['empujeEn22'] as boolean) || false;
  const jugPuntos = calcularPuntos(mano.cartas);
  const crupPuntos = calcularPuntos(dealerCards);

  if (mano.rendida) {
    // Espejo de reglas.dart: se recupera `apuesta ~/ 2` (división entera), así
    // que el neto es esa devolución menos la apuesta. Con apuestas impares esto
    // difiere de -floor(apuesta/2) (p. ej. 11 → -6, no -5): hay que calcularlo
    // igual que Dart para que el saldo autoritativo coincida con la UI.
    return {
      result: 'surrender',
      delta: Math.floor(mano.apuesta / 2) - mano.apuesta,
    };
  }
  if (jugPuntos > 21) {
    return { result: 'lose', delta: -mano.apuesta };
  }

  const esBlackjack = esUnica && mano.cartas.length === 2 && jugPuntos === 21;
  const crupierBlackjack = dealerCards.length === 2 && crupPuntos === 21;

  if (esBlackjack && crupierBlackjack) return { result: 'push', delta: 0 };
  if (esBlackjack) {
    return {
      result: 'blackjack',
      delta: Math.floor(mano.apuesta * pagoBlackjack),
    };
  }
  if (crupierBlackjack) return { result: 'lose', delta: -mano.apuesta };

  if (crupPuntos > 21) {
    if (empujeEn22 && crupPuntos === 22) return { result: 'push', delta: 0 };
    return { result: 'win', delta: mano.apuesta };
  }
  if (jugPuntos > crupPuntos) return { result: 'win', delta: mano.apuesta };
  if (jugPuntos < crupPuntos) return { result: 'lose', delta: -mano.apuesta };
  return { result: 'push', delta: 0 };
}
