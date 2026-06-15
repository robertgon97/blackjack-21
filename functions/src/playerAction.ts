import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import {
  Carta,
  EstadisticasJugador,
  Mano,
  ResultadoMano,
  acumularStats,
  calcularPuntos,
  debePedirCrupier,
  resolverMano,
} from './blackjack';
import { evaluarLogros, nombreLogro } from './logros';
import { idDiaUtc, idSemanaIso } from './semana';

interface DatosJugador {
  manos: Mano[];
  indiceMano: number;
  done: boolean;
  result: string | null;
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

    // Push a enviar TRAS la transacción (no se hace I/O externo dentro de la tx).
    // Se rellena en cada intento; al reintentar la tx se reinicia para no duplicar.
    let pushLogros: Array<{ tokens: string[]; logros: string[] }> = [];

    await db.runTransaction(async (tx) => {
      pushLogros = [];
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

      // Leaderboard semanal (Fase 10): se lee la entrada del periodo actual de
      // cada jugador en la fase de reads para poder acumular `gananciaNeta` y
      // calcular el máximo de `mejorRacha` de la semana antes de escribir.
      const ahoraLb = new Date();
      const periodoLb = idSemanaIso(ahoraLb);
      const diaProg = idDiaUtc(ahoraLb); // periodo de las misiones diarias (10c)
      const lbCol = db.collection('leaderboards').doc(periodoLb).collection('entries');
      const lbDocs = await Promise.all(
        playerUids.map((id) => tx.get(lbCol.doc(id))),
      );
      const lbDataMap = Object.fromEntries(
        playerUids.map((id, i) => [id, lbDocs[i].data() ?? {}]),
      );

      // ── FASE 2: LÓGICA PURA ────────────────────────────────────────────────

      const shoeData = shoeDoc.data() ?? { shoe: [], nextIdx: 0 };
      const shoe = [...(shoeData['shoe'] as Carta[])];
      let nextIdx = shoeData['nextIdx'] as number;

      const manos: Mano[] = playerData.manos.map((m) => ({ ...m, cartas: [...m.cartas] }));
      const idx = manoIdx ?? playerData.indiceMano;

      // Validar el índice: debe estar en rango y ser la mano que el jugador
      // tiene activa. No se permite actuar sobre una mano ya jugada o futura.
      if (!Number.isInteger(idx) || idx < 0 || idx >= manos.length) {
        throw new HttpsError('invalid-argument', 'Índice de mano fuera de rango.');
      }
      if (idx !== playerData.indiceMano) {
        throw new HttpsError('failed-precondition', 'No es el turno de esa mano.');
      }

      const mano = { ...manos[idx], cartas: [...manos[idx].cartas] };

      // Saldo disponible para nuevos compromisos = balance en Firestore menos
      // las apuestas YA comprometidas en esta ronda (que aún no se han deducido;
      // la deducción ocurre al resolver). Doblar y dividir comprometen una
      // apuesta adicional igual a la de la mano, así que deben validarse aquí
      // server-side; el cliente solo bloquea como UX, no como autoridad.
      const balanceActual = (userDataMap[uid]?.['balance'] as number) ?? 0;
      const comprometido = manos.reduce((acc, m) => acc + m.apuesta, 0);
      const saldoDisponible = balanceActual - comprometido;

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
          if (saldoDisponible < mano.apuesta) {
            throw new HttpsError('failed-precondition', 'Saldo insuficiente para doblar.');
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
          if (saldoDisponible < mano.apuesta) {
            throw new HttpsError('failed-precondition', 'Saldo insuficiente para dividir.');
          }
          // La división reparte una carta adicional a CADA mano resultante,
          // por lo que se necesitan dos cartas disponibles en el shoe.
          if (nextIdx + 1 >= shoe.length) {
            throw new HttpsError('failed-precondition', 'Shoe agotado.');
          }
          const cartaMovida = mano.cartas[1];
          const esAs = cartaMovida.valor === 'A';
          // Mano original: conserva su primera carta y recibe una nueva.
          manos[idx] = {
            ...mano,
            cartas: [mano.cartas[0], shoe[nextIdx++]],
            asPartido: esAs,
          };
          // Mano nueva: la carta movida + una carta adicional.
          const manoNueva: Mano = {
            cartas: [cartaMovida, shoe[nextIdx++]],
            apuesta: mano.apuesta,
            doblada: false,
            rendida: false,
            asPartido: esAs,
          };
          manos.splice(idx + 1, 0, manoNueva);
          // Al dividir ases, cada mano recibe una sola carta y se planta
          // automáticamente: ambas manos quedan resueltas.
          if (esAs) {
            playerData.indiceMano = idx + 2;
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
      const balanceUpdates: Array<{
        uid: string;
        delta: number;
        description: string;
        stats: EstadisticasJugador;
        ganadasRonda: number;
        manosRonda: number;
        blackjacksRonda: number;
        mainResult: ResultadoMano;
      }> = [];

      for (const [pUid, pData] of Object.entries(updatedPlayers)) {
        const esUnica = pData.manos.length === 1;
        let deltaTotal = 0;
        const resultados: ResultadoMano[] = [];

        for (const manoItem of pData.manos) {
          const { result, delta } = resolverMano(manoItem, dealerCards, esUnica, config);
          deltaTotal += delta;
          resultados.push(result);
        }

        const mainResult = [...resultados].sort(
          (a, b) => prioridad.indexOf(a) - prioridad.indexOf(b),
        )[0];

        updatedPlayers[pUid] = { ...pData, done: true, result: mainResult };

        // Estadísticas server-side (anti-trampa): se acumulan a partir de las
        // que ya tiene el usuario en Firestore (leídas en la fase de reads).
        const statsPrevias =
          userDataMap[pUid]?.['stats'] as Partial<EstadisticasJugador> | undefined;
        const nuevasStats = acumularStats(
          statsPrevias,
          pData.manos,
          resultados,
          mainResult,
          deltaTotal,
        );

        const ganadasRonda = resultados.filter(
          (r) => r === 'win' || r === 'blackjack',
        ).length;
        const blackjacksRonda = resultados.filter(
          (r) => r === 'blackjack',
        ).length;

        balanceUpdates.push({
          uid: pUid,
          delta: deltaTotal,
          description: `Ronda ${(room.round as number) || 1}: ${mainResult}`,
          stats: nuevasStats,
          ganadasRonda,
          manosRonda: pData.manos.length,
          blackjacksRonda,
          mainResult,
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

      // El balance se actualiza en users/{uid} (autoridad) y también se refleja
      // en rooms/{id}/players/{uid}.balance para que la siguiente ronda muestre y
      // valide el saldo al día (si no, quedaría el de cuando el jugador se unió).
      const roomUpdate: Record<string, unknown> = { status: 'finished' };

      for (const {
        uid: pUid,
        delta,
        description,
        stats,
        ganadasRonda,
        manosRonda,
        blackjacksRonda,
        mainResult,
      } of balanceUpdates) {
        const currentBalance = (userDataMap[pUid]?.['balance'] as number) || 0;
        const newBalance = Math.max(0, currentBalance + delta);
        const userRef = db.collection('users').doc(pUid);

        // Progreso de misiones (Fase 10c): contadores del día y de la semana.
        // arrayUnion/increment crean el doc si no existe; `reclamadas` lo gestiona
        // claimMission. El cliente no escribe aquí (firestore.rules).
        const incProgreso = {
          manosJugadas: FieldValue.increment(manosRonda),
          ganadas: FieldValue.increment(ganadasRonda),
          blackjacks: FieldValue.increment(blackjacksRonda),
          gananciaNeta: FieldValue.increment(delta),
        };
        const progresoCol = userRef.collection('progreso');
        tx.set(progresoCol.doc(diaProg), incProgreso, { merge: true });
        tx.set(progresoCol.doc(periodoLb), incProgreso, { merge: true });

        // Logros (Fase 9): se evalúan server-side con las stats ya acumuladas y
        // el saldo resultante; se agregan los nuevos al array existente.
        const logrosRaw = userDataMap[pUid]?.['logros'];
        const logrosPrevios = Array.isArray(logrosRaw)
          ? (logrosRaw as string[])
          : [];
        const logrosNuevos = evaluarLogros(stats, newBalance, logrosPrevios);
        const userUpdate: Record<string, unknown> = { balance: newBalance, stats };
        if (logrosNuevos.length > 0) {
          userUpdate['logros'] = FieldValue.arrayUnion(...logrosNuevos);
          // Recoger los tokens del usuario para notificarle el logro tras commit.
          const tokensRaw = userDataMap[pUid]?.['fcmTokens'];
          const tokens = Array.isArray(tokensRaw) ? (tokensRaw as string[]) : [];
          if (tokens.length > 0) {
            pushLogros.push({ tokens, logros: logrosNuevos });
          }
        }

        tx.update(userRef, userUpdate);

        // Leaderboard semanal (Fase 10): acumula la entrada del periodo actual.
        // gananciaNeta y manosGanadas se suman. La racha es PROPIA de la semana
        // (`rachaActualSemana`), NO la global de stats: arranca en 0 cada periodo
        // (lbPrev vacío) y sigue la misma regla que la racha global (ganar suma,
        // empate mantiene, perder/rendirse reinicia). `mejorRacha` es su máximo.
        const lbPrev = lbDataMap[pUid];
        const userData = userDataMap[pUid] ?? {};
        const rachaPrev = (lbPrev['rachaActualSemana'] as number) ?? 0;
        let rachaActualSemana: number;
        if (mainResult === 'win' || mainResult === 'blackjack') {
          rachaActualSemana = rachaPrev + 1;
        } else if (mainResult === 'push') {
          rachaActualSemana = rachaPrev;
        } else {
          rachaActualSemana = 0;
        }
        tx.set(
          lbCol.doc(pUid),
          {
            uid: pUid,
            displayName: (userData['displayName'] as string) ?? 'Jugador',
            avatar: (userData['avatar'] as string) ?? '🃏',
            gananciaNeta: ((lbPrev['gananciaNeta'] as number) ?? 0) + delta,
            manosGanadas: ((lbPrev['manosGanadas'] as number) ?? 0) + ganadasRonda,
            rachaActualSemana,
            mejorRacha: Math.max(
              (lbPrev['mejorRacha'] as number) ?? 0,
              rachaActualSemana,
            ),
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
        tx.set(userRef.collection('transactions').doc(), {
          type: delta >= 0 ? 'win' : 'loss',
          amount: Math.abs(delta),
          balance_after: newBalance,
          description,
          gameId,
          createdAt: FieldValue.serverTimestamp(),
        });
        roomUpdate[`players.${pUid}.balance`] = newBalance;
      }

      tx.update(roomRef, roomUpdate);
    });

    // Notificaciones push de logros (Fase 11b), fuera de la transacción. Un fallo
    // de envío no debe afectar al resultado de la ronda (ya persistida). Se
    // envían en paralelo para no encadenar la latencia con varios jugadores.
    await Promise.all(
      pushLogros.map(({ tokens, logros }) => {
        const cuerpo = logros.length === 1
          ? nombreLogro(logros[0])
          : `Desbloqueaste ${logros.length} logros nuevos`;
        return getMessaging()
          .sendEachForMulticast({
            tokens,
            notification: { title: '¡Logro desbloqueado!', body: cuerpo },
          })
          .catch((e) => console.error('No se pudo enviar push de logro:', e));
      }),
    );

    return { success: true };
  },
);
