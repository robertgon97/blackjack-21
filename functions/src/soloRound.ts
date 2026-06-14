import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import {
  Carta,
  Mano,
  calcularPuntos,
  debePedirCrupier,
  resolverMano,
} from './blackjack';

const VALORES_VALIDOS = [
  'A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K',
];

/** Valida que un array recibido del cliente sea una mano de cartas plausible. */
function validarCartas(cartas: unknown, minimo: number): Carta[] {
  if (!Array.isArray(cartas) || cartas.length < minimo) {
    throw new HttpsError('invalid-argument', 'Cartas inválidas.');
  }
  return cartas.map((c) => {
    const valor = (c as { valor?: unknown })?.valor;
    if (typeof valor !== 'string' || !VALORES_VALIDOS.includes(valor)) {
      throw new HttpsError('invalid-argument', 'Valor de carta inválido.');
    }
    return { valor };
  });
}

/**
 * Resuelve y PERSISTE el resultado de una ronda del juego solo (un jugador vs
 * crupier). El cliente NO puede escribir `users/{uid}.balance` (protegido por
 * reglas anti-trampa), así que esta Function —con Admin SDK— es el único camino.
 *
 * No confía en el resultado declarado por el cliente: recalcula el neto con las
 * reglas (resolverMano) sobre las cartas recibidas, valida que la apuesta no
 * supere el saldo y que el crupier haya jugado según las reglas. Limitación
 * conocida (Opción B): el cliente aún elige las cartas; el reparto server-side
 * (Opción A) queda como hardening futuro. Ver docs/features/juego-solo.md.
 */
export const resolveSoloRound = onCall(
  { region: 'southamerica-east1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    }
    const uid = request.auth.uid;
    const data = request.data as {
      manos?: unknown;
      manoCrupier?: unknown;
      seguro?: unknown;
      config?: unknown;
    };

    // ── Validar y normalizar la entrada ──────────────────────────────────────
    if (!Array.isArray(data.manos) || data.manos.length === 0) {
      throw new HttpsError('invalid-argument', 'Faltan las manos del jugador.');
    }
    const manos: Mano[] = data.manos.map((m) => {
      const mm = m as {
        cartas?: unknown;
        apuesta?: unknown;
        rendida?: unknown;
      };
      const apuesta = mm.apuesta;
      if (typeof apuesta !== 'number' || apuesta <= 0 || !Number.isFinite(apuesta)) {
        throw new HttpsError('invalid-argument', 'Apuesta inválida.');
      }
      return {
        cartas: validarCartas(mm.cartas, 2),
        apuesta: Math.floor(apuesta),
        rendida: mm.rendida === true,
      };
    });
    const manoCrupier = validarCartas(data.manoCrupier, 2);
    const seguro =
      typeof data.seguro === 'number' && data.seguro > 0
        ? Math.floor(data.seguro)
        : 0;
    const configIn = (data.config ?? {}) as Record<string, unknown>;
    const config: Record<string, unknown> = {
      pagoBlackjack:
        typeof configIn['pagoBlackjack'] === 'number'
          ? configIn['pagoBlackjack']
          : 1.5,
      empujeEn22: configIn['empujeEn22'] === true,
    };
    const h17 = configIn['h17'] === true;

    const esUnica = manos.length === 1;

    // ── Validar que el crupier jugó según las reglas ─────────────────────────
    // El crupier solo está obligado a jugar (pedir hasta no deber pedir) si hay
    // alguna mano "viva" que requiera comparación: no rendida, no pasada, y no un
    // blackjack natural (que se resuelve sin que el crupier robe).
    const hayManoViva = manos.some((m) => {
      if (m.rendida) return false;
      const pts = calcularPuntos(m.cartas);
      if (pts > 21) return false;
      const esBlackjackNatural = esUnica && m.cartas.length === 2 && pts === 21;
      return !esBlackjackNatural;
    });
    if (hayManoViva && debePedirCrupier(manoCrupier, h17)) {
      throw new HttpsError(
        'failed-precondition',
        'La mano del crupier no respeta las reglas (debió pedir carta).',
      );
    }

    // ── Recalcular el neto server-side (no se confía en el cliente) ──────────
    let neto = 0;
    for (const mano of manos) {
      neto += resolverMano(mano, manoCrupier, esUnica, config).delta;
    }
    if (seguro > 0) {
      const crupierBlackjack =
        manoCrupier.length === 2 && calcularPuntos(manoCrupier) === 21;
      neto += crupierBlackjack ? seguro * 2 : -seguro;
    }

    const comprometido =
      manos.reduce((s, m) => s + m.apuesta, 0) + seguro;

    const db = getFirestore();
    const userRef = db.collection('users').doc(uid);

    const nuevoBalance = await db.runTransaction(async (tx) => {
      const snap = await tx.get(userRef);
      if (!snap.exists) {
        throw new HttpsError('not-found', 'Perfil de usuario no encontrado.');
      }
      const balance =
        typeof snap.data()!.balance === 'number' ? snap.data()!.balance : 0;

      // No se puede comprometer (apuestas + seguro) más de lo que se tenía.
      if (comprometido > balance) {
        throw new HttpsError(
          'failed-precondition',
          'La apuesta supera tu saldo disponible.',
        );
      }

      const balanceAfter = Math.max(0, balance + neto);
      tx.update(userRef, { balance: balanceAfter });
      tx.set(userRef.collection('transactions').doc(), {
        type: neto >= 0 ? 'win' : 'loss',
        amount: Math.abs(neto),
        balance_after: balanceAfter,
        description: 'Partida individual',
        createdAt: FieldValue.serverTimestamp(),
      });
      return balanceAfter;
    });

    return { balance: nuevoBalance, neto };
  },
);
