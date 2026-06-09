import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore, FieldValue, Timestamp } from 'firebase-admin/firestore';

/**
 * Transfiere créditos entre dos usuarios de forma atómica.
 *
 * Validaciones:
 * - Usuario autenticado.
 * - toUid ≠ fromUid (no auto-transferencia).
 * - monto > 0 y entero.
 * - Saldo suficiente del emisor.
 * - Rate limit: máximo 10 transfer_out por hora (contador atómico dentro de la transacción).
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

    // Transacción atómica: rate limit + débito + crédito + historial de ambos.
    //
    // El rate limit se verifica DENTRO de la transacción usando los campos
    // transferCount y transferWindowStart del documento del emisor, evitando
    // la race condition de TOCTOU que habría si se hiciera una consulta previa.
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

      const fromData = fromDoc.data()!;

      // ── Rate limit atómico ─────────────────────────────────────────────────
      const windowStart = fromData.transferWindowStart as Timestamp | undefined;
      const nowMs = Date.now();
      let transferCount: number = (fromData.transferCount as number | null) ?? 0;

      // Si la ventana expiró (>1 hora), reiniciamos el contador.
      const windowExpired =
        !windowStart || nowMs - windowStart.toMillis() > 60 * 60 * 1000;
      if (windowExpired) {
        transferCount = 0;
      }

      if (transferCount >= 10) {
        throw new HttpsError(
          'resource-exhausted',
          'Límite de 10 transferencias por hora alcanzado.',
        );
      }
      // ──────────────────────────────────────────────────────────────────────

      const fromBalance = (fromData.balance as number) ?? 0;
      if (fromBalance < monto) {
        throw new HttpsError('failed-precondition', 'Saldo insuficiente.');
      }

      const toData = toDoc.data()!;
      const toBalance = (toData.balance as number) ?? 0;
      const fromName = (fromData.displayName as string) ?? 'usuario';
      const toName = (toData.displayName as string) ?? 'usuario';
      const now = FieldValue.serverTimestamp();

      // Actualizar balances y contador de rate limit del emisor.
      tx.update(fromRef, {
        balance: fromBalance - monto,
        transferCount: transferCount + 1,
        // Solo actualizamos transferWindowStart cuando se inicia una nueva ventana.
        ...(windowExpired ? { transferWindowStart: now } : {}),
      });
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
