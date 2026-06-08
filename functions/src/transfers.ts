import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

/**
 * Transfiere créditos entre dos usuarios de forma atómica.
 *
 * Validaciones:
 * - Usuario autenticado.
 * - toUid ≠ fromUid (no auto-transferencia).
 * - monto > 0 y entero.
 * - Saldo suficiente del emisor.
 * - Rate limit: máximo 10 transfer_out por hora.
 */
export const transferCredits = onCall(
  { region: 'southamerica-east1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    }

    const fromUid = request.auth.uid;
    const data = request.data as { toUid?: unknown; monto?: unknown };
    const { toUid, monto } = data;

    if (typeof toUid !== 'string' || !toUid) {
      throw new HttpsError('invalid-argument', 'toUid inválido.');
    }
    if (typeof monto !== 'number' || !Number.isInteger(monto) || monto <= 0) {
      throw new HttpsError('invalid-argument', 'El monto debe ser un entero positivo.');
    }
    if (fromUid === toUid) {
      throw new HttpsError('invalid-argument', 'No puedes transferirte créditos a ti mismo.');
    }

    const db = getFirestore();

    // Rate limit: máximo 10 transfer_out por hora.
    const unaHoraAtras = new Date(Date.now() - 60 * 60 * 1000);
    const recientes = await db
      .collection('users')
      .doc(fromUid)
      .collection('transactions')
      .where('type', '==', 'transfer_out')
      .where('createdAt', '>=', unaHoraAtras)
      .count()
      .get();

    if (recientes.data().count >= 10) {
      throw new HttpsError(
        'resource-exhausted',
        'Límite de 10 transferencias por hora alcanzado.',
      );
    }

    // Transacción atómica: débito + crédito + historial de ambos.
    await db.runTransaction(async (tx) => {
      const fromRef = db.collection('users').doc(fromUid);
      const toRef = db.collection('users').doc(toUid);

      const [fromDoc, toDoc] = await Promise.all([tx.get(fromRef), tx.get(toRef)]);

      if (!fromDoc.exists) {
        throw new HttpsError('not-found', 'Usuario emisor no encontrado.');
      }
      if (!toDoc.exists) {
        throw new HttpsError('not-found', 'Usuario receptor no encontrado.');
      }

      const fromBalance = (fromDoc.data()?.balance as number) ?? 0;
      if (fromBalance < monto) {
        throw new HttpsError('failed-precondition', 'Saldo insuficiente.');
      }

      const toBalance = (toDoc.data()?.balance as number) ?? 0;
      const fromName = (fromDoc.data()?.displayName as string) ?? 'usuario';
      const toName = (toDoc.data()?.displayName as string) ?? 'usuario';
      const now = FieldValue.serverTimestamp();

      tx.update(fromRef, { balance: fromBalance - monto });
      tx.update(toRef, { balance: toBalance + monto });

      tx.set(fromRef.collection('transactions').doc(), {
        type: 'transfer_out',
        amount: monto,
        balance_after: fromBalance - monto,
        description: `Transferencia a ${toName}`,
        toUid,
        createdAt: now,
      });

      tx.set(toRef.collection('transactions').doc(), {
        type: 'transfer_in',
        amount: monto,
        balance_after: toBalance + monto,
        description: `Transferencia de ${fromName}`,
        fromUid,
        createdAt: now,
      });
    });

    return { success: true };
  },
);
