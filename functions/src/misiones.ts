// ─────────────────────────────────────────────────────────────────────────────
// Misiones diarias/semanales (Fase 10c). El progreso lo acumula `playerAction`
// en users/{uid}/progreso/{periodo} (periodo = día UTC o semana ISO). Esta
// función paga la recompensa de una misión completada, de forma idempotente.
//
// Espejo del catálogo Dart en lib/features/misiones/domain/mision.dart: los id,
// metas y recompensas deben coincidir.
// ─────────────────────────────────────────────────────────────────────────────

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { idDiaUtc, idSemanaIso } from './semana';

interface DefMision {
  id: string;
  tipo: 'diaria' | 'semanal';
  campo: string; // métrica en el doc de progreso
  meta: number;
  recompensa: number;
}

const MISIONES: DefMision[] = [
  { id: 'd_jugar', tipo: 'diaria', campo: 'manosJugadas', meta: 5, recompensa: 100 },
  { id: 'd_ganar', tipo: 'diaria', campo: 'ganadas', meta: 3, recompensa: 150 },
  { id: 'd_blackjack', tipo: 'diaria', campo: 'blackjacks', meta: 1, recompensa: 200 },
  { id: 's_jugar', tipo: 'semanal', campo: 'manosJugadas', meta: 50, recompensa: 500 },
  { id: 's_ganar', tipo: 'semanal', campo: 'ganadas', meta: 20, recompensa: 700 },
  { id: 's_ganancia', tipo: 'semanal', campo: 'gananciaNeta', meta: 2000, recompensa: 1000 },
];

/**
 * Reclama la recompensa de una misión completada. Idempotente: valida el
 * progreso del periodo y que la misión no se haya reclamado ya (anti-trampa: el
 * cliente no puede escribir `balance` ni el progreso).
 */
export const claimMission = onCall(
  { region: 'southamerica-east1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    }
    const uid = request.auth.uid;
    const missionId = (request.data as { missionId?: unknown })?.missionId;
    if (typeof missionId !== 'string') {
      throw new HttpsError('invalid-argument', 'missionId inválido.');
    }
    const mision = MISIONES.find((m) => m.id === missionId);
    if (!mision) {
      throw new HttpsError('not-found', 'Misión no encontrada.');
    }

    const periodo =
      mision.tipo === 'diaria' ? idDiaUtc(new Date()) : idSemanaIso(new Date());
    const db = getFirestore();
    const userRef = db.collection('users').doc(uid);
    const progRef = userRef.collection('progreso').doc(periodo);

    const balance = await db.runTransaction(async (tx) => {
      const [userSnap, progSnap] = await Promise.all([
        tx.get(userRef),
        tx.get(progRef),
      ]);
      if (!userSnap.exists) {
        throw new HttpsError('not-found', 'Perfil de usuario no encontrado.');
      }
      const prog = progSnap.data() ?? {};

      const reclamadas = Array.isArray(prog['reclamadas'])
        ? (prog['reclamadas'] as string[])
        : [];
      if (reclamadas.includes(missionId)) {
        throw new HttpsError('already-exists', 'Ya reclamaste esta misión.');
      }

      const valor =
        typeof prog[mision.campo] === 'number' ? (prog[mision.campo] as number) : 0;
      if (valor < mision.meta) {
        throw new HttpsError(
          'failed-precondition',
          'Aún no has completado esta misión.',
        );
      }

      const bal =
        typeof userSnap.data()!['balance'] === 'number'
          ? (userSnap.data()!['balance'] as number)
          : 0;
      const balanceAfter = bal + mision.recompensa;

      tx.update(userRef, { balance: balanceAfter });
      tx.set(
        progRef,
        { reclamadas: FieldValue.arrayUnion(missionId) },
        { merge: true },
      );
      tx.set(userRef.collection('transactions').doc(), {
        type: 'mission_reward',
        amount: mision.recompensa,
        balance_after: balanceAfter,
        description: `Misión: ${missionId}`,
        createdAt: FieldValue.serverTimestamp(),
      });

      return balanceAfter;
    });

    return { balance, amount: mision.recompensa };
  },
);
