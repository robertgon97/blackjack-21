import { onRequest } from 'firebase-functions/v2/https';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import * as crypto from 'crypto';

const MONTO = 200; // créditos por anuncio recompensado verificado

// Claves públicas de verificación de AdMob (rotan; se cachean 24 h).
const URL_CLAVES = 'https://www.gstatic.com/admob/reward/verifier-keys.json';
let cacheClaves: Record<string, string> | null = null;
let cacheTs = 0;

async function obtenerClaves(): Promise<Record<string, string>> {
  if (cacheClaves && Date.now() - cacheTs < 24 * 60 * 60 * 1000) {
    return cacheClaves;
  }
  const res = await fetch(URL_CLAVES);
  const data = (await res.json()) as {
    keys: Array<{ keyId: number; pem: string }>;
  };
  const map: Record<string, string> = {};
  for (const k of data.keys) map[String(k.keyId)] = k.pem;
  cacheClaves = map;
  cacheTs = Date.now();
  return map;
}

/**
 * Endpoint de **Server-Side Verification** de AdMob (Fase 11c). Google lo llama
 * cuando un usuario completa un anuncio recompensado, con los datos firmados.
 * Verificamos la firma ECDSA con la clave pública de Google y, solo si es
 * válida, acreditamos la recompensa (idempotente por `transaction_id`).
 *
 * La URL pública de esta función se configura en la consola de AdMob (unidad
 * recompensada → verificación del servidor). Es pública a propósito: la firma es
 * la autenticación, no App Check.
 */
export const admobSsv = onRequest(
  { region: 'southamerica-east1' },
  async (req, res) => {
    try {
      const query = req.url.includes('?') ? req.url.split('?')[1] : '';
      // El contenido firmado es todo lo anterior a `&signature=`.
      const sigIdx = query.indexOf('&signature=');
      if (sigIdx < 0) {
        res.status(400).send('missing signature');
        return;
      }
      const contenido = query.slice(0, sigIdx);
      const params = new URLSearchParams(query);
      const signature = params.get('signature');
      const keyId = params.get('key_id');
      const userId = params.get('user_id');
      const txId = params.get('transaction_id');

      if (!signature || !keyId || !userId || !txId) {
        res.status(400).send('missing params');
        return;
      }

      const claves = await obtenerClaves();
      const pem = claves[keyId];
      if (!pem) {
        res.status(400).send('unknown key');
        return;
      }

      const valida = crypto.verify(
        'sha256',
        Buffer.from(contenido),
        pem,
        Buffer.from(signature, 'base64url'),
      );
      if (!valida) {
        res.status(401).send('invalid signature');
        return;
      }

      // Acreditar idempotente: el doc adRewards/{txId} marca el reclamo procesado.
      const db = getFirestore();
      const userRef = db.collection('users').doc(userId);
      const rewardRef = userRef.collection('adRewards').doc(txId);
      await db.runTransaction(async (tx) => {
        const [userSnap, rewSnap] = await Promise.all([
          tx.get(userRef),
          tx.get(rewardRef),
        ]);
        if (rewSnap.exists || !userSnap.exists) return; // ya procesado o sin perfil
        const bal =
          typeof userSnap.data()!['balance'] === 'number'
            ? (userSnap.data()!['balance'] as number)
            : 0;
        const balanceAfter = bal + MONTO;
        tx.update(userRef, {
          balance: balanceAfter,
          lastAdReward: FieldValue.serverTimestamp(),
        });
        tx.set(rewardRef, {
          amount: MONTO,
          createdAt: FieldValue.serverTimestamp(),
        });
        tx.set(userRef.collection('transactions').doc(), {
          type: 'ad_reward',
          amount: MONTO,
          balance_after: balanceAfter,
          description: 'Recompensa por anuncio',
          createdAt: FieldValue.serverTimestamp(),
        });
      });

      res.status(200).send('ok');
    } catch (e) {
      console.error('admobSsv error:', e);
      res.status(500).send('error');
    }
  },
);
