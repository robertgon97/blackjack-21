import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore, FieldValue, Timestamp } from 'firebase-admin/firestore';
import { idDiaUtc } from './semana';

const MONTO_BASE = 500; // recompensa del día 1 de la racha
const INCREMENTO = 100; // crece por día consecutivo…
const TOPE_RACHA = 7; // …hasta este día (día 7 = 1100)

/** Recompensa del día [racha] de la racha (creciente, con tope). */
function montoPorRacha(racha: number): number {
  const dia = Math.max(1, Math.min(racha, TOPE_RACHA));
  return MONTO_BASE + (dia - 1) * INCREMENTO;
}

/**
 * Acredita el **bono diario** con **racha** de días consecutivos (Fase 10b).
 * Una vez por día calendario (UTC). Sirve también de recarga cuando el saldo del
 * juego solo llega a $0.
 *
 * El cliente NO puede escribir `balance`, `dailyStreak` ni `lastDailyBonusDay`
 * (protegidos en firestore.rules). El control anti-abuso vive aquí: el día se
 * compara DENTRO de la transacción sobre el snapshot transaccional.
 */
export const claimDailyBonus = onCall(
  { region: 'southamerica-east1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    }
    const uid = request.auth.uid;
    const db = getFirestore();
    const userRef = db.collection('users').doc(uid);

    const resultado = await db.runTransaction(async (tx) => {
      // Dentro de la transacción para que el día refleje el instante real del
      // intento (importante si la transacción se reintenta cerca de medianoche).
      const ahora = new Date();
      const hoy = idDiaUtc(ahora);
      const ayer = idDiaUtc(new Date(ahora.getTime() - 24 * 60 * 60 * 1000));

      const snap = await tx.get(userRef);
      if (!snap.exists) {
        throw new HttpsError('not-found', 'Perfil de usuario no encontrado.');
      }
      const data = snap.data()!;

      // Día del último reclamo. Compat con cuentas previas a la Fase 10b que solo
      // tienen el timestamp `lastDailyBonus` (sin `lastDailyBonusDay`).
      const lastDay = data.lastDailyBonusDay as string | undefined;
      const lastTs = data.lastDailyBonus as Timestamp | undefined;
      const ultimoDia = lastDay ?? (lastTs ? idDiaUtc(lastTs.toDate()) : undefined);

      if (ultimoDia === hoy) {
        throw new HttpsError(
          'failed-precondition',
          'Ya reclamaste tu bono diario hoy. Vuelve mañana.',
        );
      }

      // La racha continúa si el último reclamo fue ayer; si no, vuelve a 1.
      const rachaPrev =
        typeof data.dailyStreak === 'number' ? data.dailyStreak : 0;
      const racha = ultimoDia === ayer ? rachaPrev + 1 : 1;
      const monto = montoPorRacha(racha);

      const balance = typeof data.balance === 'number' ? data.balance : 0;
      const balanceAfter = balance + monto;

      tx.update(userRef, {
        balance: balanceAfter,
        dailyStreak: racha,
        lastDailyBonusDay: hoy,
        lastDailyBonus: FieldValue.serverTimestamp(),
      });
      tx.set(userRef.collection('transactions').doc(), {
        type: 'bonus_daily',
        amount: monto,
        balance_after: balanceAfter,
        description: `Bono diario (día ${racha})`,
        createdAt: FieldValue.serverTimestamp(),
      });

      return { balance: balanceAfter, amount: monto, streak: racha };
    });

    return resultado;
  },
);
