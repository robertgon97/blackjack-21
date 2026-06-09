import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

/**
 * Acredita el bono de +500 créditos al convertir una cuenta anónima en permanente
 * (account linking). Ver diseño en docs/features/conversion-cuenta.md.
 *
 * El cliente llama esta Function DESPUÉS de `linkWithCredential` y de forzar el
 * refresco del token (`getIdToken(true)`), de modo que el token ya no sea anónimo.
 *
 * Validaciones:
 * - Usuario autenticado.
 * - El token ya NO es anónimo (`sign_in_provider != 'anonymous'`): impide cobrar
 *   antes de convertir.
 * - Idempotencia y origen anónimo se verifican DENTRO de la transacción sobre el
 *   snapshot transaccional, evitando una carrera TOCTOU entre llamadas concurrentes.
 */
export const claimConversionBonus = onCall(
  { region: 'southamerica-east1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    }

    // El token debe haber dejado de ser anónimo (la conversión ya ocurrió).
    const provider = request.auth.token.firebase?.sign_in_provider;
    if (provider === 'anonymous') {
      throw new HttpsError(
        'failed-precondition',
        'La cuenta sigue siendo anónima; vincula una credencial antes de cobrar el bono.',
      );
    }

    const uid = request.auth.uid;
    const db = getFirestore();
    const userRef = db.collection('users').doc(uid);

    // Toda la lógica de guardas y escritura ocurre dentro de la transacción.
    const resultado = await db.runTransaction(async (tx) => {
      const snap = await tx.get(userRef);
      if (!snap.exists) {
        throw new HttpsError('not-found', 'Perfil de usuario no encontrado.');
      }

      const data = snap.data()!;

      // (1) Idempotencia — primero, para que los reintentos post-pago sean no-op
      //     sin importar el valor de isAnonymous (que ya estará en false).
      if (data.conversionBonusGranted === true) {
        return { yaAcreditado: true };
      }

      // (2) Confirma origen anónimo. No usar 'unauthenticated' (el usuario SÍ está
      //     autenticado): es una precondición de negocio incumplida.
      if (data.isAnonymous !== true) {
        throw new HttpsError(
          'failed-precondition',
          'La cuenta no fue originalmente anónima y no puede recibir el bono de conversión.',
        );
      }

      // Validación en runtime: `as number` no protege si el campo viniera con
      // un tipo inesperado (un string no activaría `?? 0` y daría NaN al sumar).
      const balance = typeof data.balance === 'number' ? data.balance : 0;
      const balanceAfter = balance + 500;
      const now = FieldValue.serverTimestamp();

      tx.update(userRef, {
        balance: balanceAfter,
        conversionBonusGranted: true,
        isAnonymous: false,
      });

      tx.set(userRef.collection('transactions').doc(), {
        type: 'bonus_conversion',
        amount: 500,
        balance_after: balanceAfter,
        description: 'Bono por convertir cuenta demo a permanente',
        createdAt: now,
      });

      return { yaAcreditado: false };
    });

    return { success: true, ...resultado };
  },
);
