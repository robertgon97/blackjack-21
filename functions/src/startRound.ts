import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

const PALOS = ['picas', 'corazones', 'diamantes', 'treboles'] as const;
const VALORES = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'] as const;

interface Carta {
  palo: string;
  valor: string;
}

function crearShoe(numBarajas: number): Carta[] {
  const shoe: Carta[] = [];
  for (let i = 0; i < numBarajas; i++) {
    for (const palo of PALOS) {
      for (const valor of VALORES) {
        shoe.push({ palo, valor });
      }
    }
  }
  // Fisher-Yates shuffle
  for (let i = shoe.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [shoe[i], shoe[j]] = [shoe[j], shoe[i]];
  }
  return shoe;
}

/**
 * Inicia una ronda multijugador:
 * - Valida que el caller es el host y que la sala está en 'betting' con todos listos.
 * - Genera el shoe, reparte 2 cartas a cada jugador y 2 al crupier (1 oculta).
 * - Crea el documento games/{gameId} con el estado inicial.
 * - Actualiza la sala: status = 'playing', currentGameId = gameId.
 */
export const startRound = onCall(
  { region: 'southamerica-east1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    }

    const { roomId } = request.data as { roomId?: unknown };
    if (typeof roomId !== 'string' || !roomId) {
      throw new HttpsError('invalid-argument', 'roomId inválido.');
    }

    const db = getFirestore();
    const roomRef = db.collection('rooms').doc(roomId);

    await db.runTransaction(async (tx) => {
      const roomDoc = await tx.get(roomRef);
      if (!roomDoc.exists) {
        throw new HttpsError('not-found', 'Sala no encontrada.');
      }

      const room = roomDoc.data()!;
      if (room.hostUid !== request.auth!.uid) {
        throw new HttpsError('permission-denied', 'Solo el host puede iniciar la ronda.');
      }
      if (room.status !== 'betting') {
        throw new HttpsError('failed-precondition', 'La sala no está en fase de apuestas.');
      }

      const players = (room.players as Record<string, Record<string, unknown>>) ?? {};
      const activePlayers = Object.entries(players).filter(
        ([, p]) => !p['isSpectator'],
      );

      if (activePlayers.length === 0) {
        throw new HttpsError('failed-precondition', 'No hay jugadores activos.');
      }

      const allReady = activePlayers.every(([, p]) => p['ready'] === true);
      if (!allReady) {
        throw new HttpsError('failed-precondition', 'No todos los jugadores están listos.');
      }

      const config = (room.config as Record<string, unknown>) ?? {};
      const numBarajas = (config['numBarajas'] as number) || 6;
      const shoe = crearShoe(numBarajas);
      let shoeIdx = 0;

      const dealerCards: Carta[] = [shoe[shoeIdx++], shoe[shoeIdx++]];

      const gamePlayers: Record<string, unknown> = {};
      for (const [uid, player] of activePlayers) {
        const apuesta = (player['apuesta'] as number) || (config['apuestaMin'] as number) || 10;
        gamePlayers[uid] = {
          manos: [
            {
              cartas: [shoe[shoeIdx++], shoe[shoeIdx++]],
              apuesta,
              doblada: false,
              rendida: false,
              asPartido: false,
            },
          ],
          indiceMano: 0,
          done: false,
          result: null,
        };
      }

      const gameRef = db.collection('games').doc();
      const gameId = gameRef.id;

      // El shoe se guarda en una sub-colección privada (no legible por clientes).
      const shoeRef = gameRef.collection('serverData').doc('current');

      tx.set(gameRef, {
        roomId,
        round: (room.round as number || 0) + 1,
        phase: 'player_turns',
        dealerCards,
        dealerHidden: true,
        players: gamePlayers,
        updatedAt: FieldValue.serverTimestamp(),
      });

      tx.set(shoeRef, { shoe, nextIdx: shoeIdx });

      tx.update(roomRef, {
        status: 'playing',
        currentGameId: gameId,
        round: FieldValue.increment(1),
      });
    });

    return { success: true };
  },
);
