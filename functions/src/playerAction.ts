import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

interface Carta {
  palo: string;
  valor: string;
}

interface Mano {
  cartas: Carta[];
  apuesta: number;
  doblada: boolean;
  rendida: boolean;
  asPartido: boolean;
}

interface DatosJugador {
  manos: Mano[];
  indiceMano: number;
  done: boolean;
  result: string | null;
}

function calcularPuntos(cartas: Carta[]): number {
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

function debePedirCrupier(cartas: Carta[], h17: boolean): boolean {
  const total = calcularPuntos(cartas);
  if (total < 17) return true;
  if (total > 17) return false;
  if (!h17) return false;
  let tieneAs = false;
  let suma = 0;
  for (const c of cartas) {
    if (c.valor === 'A') tieneAs = true;
    else if (['J', 'Q', 'K'].includes(c.valor)) suma += 10;
    else suma += parseInt(c.valor, 10);
  }
  return tieneAs && suma === 6;
}

function resolverMano(
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
    return { result: 'surrender', delta: -Math.floor(mano.apuesta / 2) };
  }
  if (jugPuntos > 21) {
    return { result: 'lose', delta: -mano.apuesta };
  }

  const esBlackjack =
    esUnica && mano.cartas.length === 2 && jugPuntos === 21;
  const crupierBlackjack = dealerCards.length === 2 && crupPuntos === 21;

  if (esBlackjack && crupierBlackjack) return { result: 'push', delta: 0 };
  if (esBlackjack) {
    return { result: 'blackjack', delta: Math.floor(mano.apuesta * pagoBlackjack) };
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

/**
 * Procesa la acción de un jugador en su turno.
 * Acciones: 'pedir' | 'plantarse' | 'doblar' | 'rendirse' | 'dividir'
 *
 * IMPORTANTE: todos los tx.get() ocurren antes de cualquier tx.write/update/set
 * (requisito del SDK de Firestore en transacciones).
 */
export const playerAction = onCall(
  { region: 'southamerica-east1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    }

    const uid = request.auth.uid;
    const data = request.data as {
      roomId?: unknown;
      accion?: unknown;
      manoIdx?: unknown;
    };
    const { roomId, accion, manoIdx: rawManoIdx } = data;

    if (typeof roomId !== 'string' || !roomId) {
      throw new HttpsError('invalid-argument', 'roomId inválido.');
    }
    if (typeof accion !== 'string') {
      throw new HttpsError('invalid-argument', 'accion inválida.');
    }

    const manoIdx = typeof rawManoIdx === 'number' ? rawManoIdx : undefined;
    const db = getFirestore();
    const roomRef = db.collection('rooms').doc(roomId as string);

    await db.runTransaction(async (tx) => {
      // ── FASE 1: TODOS LOS READS ───────────────────────────────────────────

      const roomDoc = await tx.get(roomRef);
      if (!roomDoc.exists) throw new HttpsError('not-found', 'Sala no encontrada.');

      const room = roomDoc.data()!;
      if (room.status !== 'playing') {
        throw new HttpsError('failed-precondition', 'La sala no está jugando.');
      }

      const gameId = room.currentGameId as string | undefined;
      if (!gameId) throw new HttpsError('failed-precondition', 'No hay partida activa.');

      const gameRef = db.collection('games').doc(gameId);
      const shoeRef = gameRef.collection('serverData').doc('current');

      const [gameDoc, shoeDoc] = await Promise.all([
        tx.get(gameRef),
        tx.get(shoeRef),
      ]);

      if (!gameDoc.exists) throw new HttpsError('not-found', 'Partida no encontrada.');

      const game = gameDoc.data()!;
      if (game.phase !== 'player_turns') {
        throw new HttpsError('failed-precondition', 'No es la fase de turnos.');
      }

      const playerData = (game.players as Record<string, DatosJugador>)[uid];
      if (!playerData) throw new HttpsError('not-found', 'Jugador no encontrado en la partida.');
      if (playerData.done) return; // idempotente

      // Leer todos los documentos de usuario anticipadamente (necesario antes de cualquier write).
      const playerUids = Object.keys(game.players as Record<string, unknown>);
      const userRefs = playerUids.map((id) => db.collection('users').doc(id));
      const userDocs = await Promise.all(userRefs.map((r) => tx.get(r)));
      const userDataMap = Object.fromEntries(
        playerUids.map((id, i) => [id, userDocs[i].data() ?? {}]),
      );

      // ── FASE 2: LÓGICA PURA ────────────────────────────────────────────────

      const shoeData = shoeDoc.data() ?? { shoe: [], nextIdx: 0 };
      const shoe = [...(shoeData['shoe'] as Carta[])];
      let nextIdx = shoeData['nextIdx'] as number;

      const manos: Mano[] = playerData.manos.map((m) => ({ ...m, cartas: [...m.cartas] }));
      const idx = manoIdx ?? playerData.indiceMano;
      const mano = { ...manos[idx], cartas: [...manos[idx].cartas] };

      switch (accion) {
        case 'pedir': {
          if (nextIdx >= shoe.length) throw new HttpsError('failed-precondition', 'Shoe agotado.');
          mano.cartas = [...mano.cartas, shoe[nextIdx++]];
          manos[idx] = mano;
          const puntos = calcularPuntos(mano.cartas);
          if (puntos >= 21) {
            playerData.indiceMano = idx + 1;
            if (playerData.indiceMano >= manos.length) playerData.done = true;
          }
          break;
        }
        case 'plantarse': {
          playerData.indiceMano = idx + 1;
          if (playerData.indiceMano >= manos.length) playerData.done = true;
          break;
        }
        case 'doblar': {
          if (mano.cartas.length !== 2 || mano.doblada) {
            throw new HttpsError('failed-precondition', 'No puedes doblar ahora.');
          }
          if (nextIdx >= shoe.length) throw new HttpsError('failed-precondition', 'Shoe agotado.');
          mano.cartas = [...mano.cartas, shoe[nextIdx++]];
          mano.apuesta *= 2;
          mano.doblada = true;
          manos[idx] = mano;
          playerData.indiceMano = idx + 1;
          if (playerData.indiceMano >= manos.length) playerData.done = true;
          break;
        }
        case 'rendirse': {
          if (manos.length !== 1 || mano.cartas.length !== 2) {
            throw new HttpsError('failed-precondition', 'No puedes rendirte ahora.');
          }
          mano.rendida = true;
          manos[idx] = mano;
          playerData.done = true;
          break;
        }
        case 'dividir': {
          if (
            mano.cartas.length !== 2 ||
            mano.cartas[0].valor !== mano.cartas[1].valor ||
            manos.length >= 4
          ) {
            throw new HttpsError('failed-precondition', 'No puedes dividir ahora.');
          }
          if (nextIdx >= shoe.length) throw new HttpsError('failed-precondition', 'Shoe agotado.');
          const cartaMovida = mano.cartas[1];
          const esAs = cartaMovida.valor === 'A';
          const manoNueva: Mano = {
            cartas: [cartaMovida],
            apuesta: mano.apuesta,
            doblada: false,
            rendida: false,
            asPartido: esAs,
          };
          manos[idx] = { ...mano, cartas: [mano.cartas[0], shoe[nextIdx++]], asPartido: esAs };
          manos.splice(idx + 1, 0, manoNueva);
          if (esAs) {
            playerData.indiceMano = idx + 1;
            if (playerData.indiceMano >= manos.length) playerData.done = true;
          }
          break;
        }
        default:
          throw new HttpsError('invalid-argument', `Acción desconocida: ${accion as string}`);
      }

      playerData.manos = manos;

      const updatedPlayers: Record<string, DatosJugador> = {
        ...(game.players as Record<string, DatosJugador>),
        [uid]: playerData,
      };

      const allDone = Object.values(updatedPlayers).every((p) => p.done);

      // ── FASE 3: WRITES ────────────────────────────────────────────────────

      if (!allDone) {
        tx.update(gameRef, {
          [`players.${uid}`]: playerData,
          updatedAt: FieldValue.serverTimestamp(),
        });
        tx.update(shoeRef, { shoe, nextIdx });
        return;
      }

      // Todos terminaron: crupier juega, se resuelve la ronda.
      const config = (room.config as Record<string, unknown>) ?? {};
      const h17 = (config['crupierPideEn17Suave'] as boolean) || false;

      let dealerCards = [...(game.dealerCards as Carta[])];

      const hayManoViva = Object.values(updatedPlayers).some((p) =>
        p.manos.some((m) => !m.rendida && calcularPuntos(m.cartas) <= 21),
      );

      if (hayManoViva) {
        while (debePedirCrupier(dealerCards, h17)) {
          if (nextIdx >= shoe.length) break;
          dealerCards = [...dealerCards, shoe[nextIdx++]];
        }
      }

      // Calcular resultados.
      const prioridad = ['blackjack', 'win', 'push', 'surrender', 'lose'];
      const balanceUpdates: Array<{ uid: string; delta: number; description: string }> = [];

      for (const [pUid, pData] of Object.entries(updatedPlayers)) {
        const esUnica = pData.manos.length === 1;
        let deltaTotal = 0;
        const resultados: string[] = [];

        for (const manoItem of pData.manos) {
          const { result, delta } = resolverMano(manoItem, dealerCards, esUnica, config);
          deltaTotal += delta;
          resultados.push(result);
        }

        const mainResult = [...resultados].sort(
          (a, b) => prioridad.indexOf(a) - prioridad.indexOf(b),
        )[0];

        updatedPlayers[pUid] = { ...pData, done: true, result: mainResult };
        balanceUpdates.push({
          uid: pUid,
          delta: deltaTotal,
          description: `Ronda ${(room.round as number) || 1}: ${mainResult}`,
        });
      }

      tx.update(gameRef, {
        players: updatedPlayers,
        dealerCards,
        dealerHidden: false,
        phase: 'resolved',
        updatedAt: FieldValue.serverTimestamp(),
      });
      tx.update(shoeRef, { shoe, nextIdx });
      tx.update(roomRef, { status: 'finished' });

      for (const { uid: pUid, delta, description } of balanceUpdates) {
        const currentBalance = (userDataMap[pUid]?.['balance'] as number) || 0;
        const newBalance = Math.max(0, currentBalance + delta);
        const userRef = db.collection('users').doc(pUid);

        tx.update(userRef, { balance: newBalance });
        tx.set(userRef.collection('transactions').doc(), {
          type: delta >= 0 ? 'win' : 'loss',
          amount: Math.abs(delta),
          balance_after: newBalance,
          description,
          gameId,
          createdAt: FieldValue.serverTimestamp(),
        });
      }
    });

    return { success: true };
  },
);
