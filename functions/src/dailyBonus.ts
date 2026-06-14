import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore, FieldValue, Timestamp } from 'firebase-admin/firestore';

const MONTO_BONO = 500;
const COOLDOWN_MS = 24 * 60 * 60 * 1000; // 24 horas

/**
 * Acredita el **bono diario** de créditos (una vez cada 24 h). Sirve también de
 * recarga cuando el saldo del juego solo llega a $0.
 *
 * El cliente NO puede escribir `balance` ni `lastDailyBonus` (protegidos en
 * firestore.rules), así que el control anti-abuso vive aquí: la ventana de 24 h
 * se valida DENTRO de la transacción sobre el snapshot transaccional, evitando
 * carreras entre llamadas concurrentes.
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
      const snap = await tx.get(userRef);
      if (!snap.exists) {
        throw new HttpsError('not-found', 'Perfil de usuario no encontrado.');
      }
      const data = snap.data()!;

      const last = data.lastDailyBonus as Timestamp | undefined;
      const ahora = Date.now();
      if (last && ahora - last.toMillis() < COOLDOWN_MS) {
        const restanteMs = COOLDOWN_MS - (ahora - last.toMillis());
        const horas = Math.ceil(restanteMs / (60 * 60 * 1000));
        throw new HttpsError(
          'failed-precondition',
          `Ya reclamaste tu bono diario. Vuelve en ${horas} h.`,
        );
      }

      const balance = typeof data.balance === 'number' ? data.balance : 0;
      const balanceAfter = balance + MONTO_BONO;

      tx.update(userRef, {
        balance: balanceAfter,
        lastDailyBonus: FieldValue.serverTimestamp(),
      });
      tx.set(userRef.collection('transactions').doc(), {
        type: 'bonus_daily',
        amount: MONTO_BONO,
        balance_after: balanceAfter,
        description: 'Bono diario',
        createdAt: FieldValue.serverTimestamp(),
      });

      return balanceAfter;
    });

    return { balance: resultado, amount: MONTO_BONO };
  },
);
