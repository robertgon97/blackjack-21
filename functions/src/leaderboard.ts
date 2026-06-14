// ─────────────────────────────────────────────────────────────────────────────
// Mantenimiento del leaderboard semanal (Fase 10).
//
// Las entradas las escribe `playerAction` en `leaderboards/{periodo}/entries/{uid}`
// (periodo = semana ISO). El periodo "se abre" implícitamente al cambiar la
// semana; esta función programada "cierra" los periodos viejos purgándolos para
// que la colección no crezca sin límite.
// ─────────────────────────────────────────────────────────────────────────────

import { onSchedule } from 'firebase-functions/v2/scheduler';
import { getFirestore } from 'firebase-admin/firestore';
import { idSemanaIso } from './semana';

/** Semanas de historial que se conservan (la actual + las anteriores). */
const SEMANAS_RETENER = 8;
const MS_POR_SEMANA = 7 * 24 * 60 * 60 * 1000;

/**
 * Cada lunes purga los periodos del leaderboard anteriores a las últimas
 * [SEMANAS_RETENER] semanas. Idempotente: si no hay nada que borrar, no hace
 * nada.
 */
export const purgarLeaderboards = onSchedule(
  {
    schedule: 'every monday 03:00',
    timeZone: 'America/Sao_Paulo',
    region: 'southamerica-east1',
  },
  async () => {
    const db = getFirestore();

    const aRetener = new Set<string>();
    const ahora = Date.now();
    for (let i = 0; i < SEMANAS_RETENER; i++) {
      aRetener.add(idSemanaIso(new Date(ahora - i * MS_POR_SEMANA)));
    }

    // listDocuments incluye documentos "fantasma" (sin campos pero con
    // subcolección entries), que es justo como quedan los periodos.
    // Se borran en paralelo: si el job falló varias semanas, pueden acumularse
    // varios periodos vencidos y los borrados secuenciales rozarían el timeout.
    const periodos = await db.collection('leaderboards').listDocuments();
    await Promise.all(
      periodos
        .filter((ref) => !aRetener.has(ref.id))
        .map((ref) => db.recursiveDelete(ref)),
    );
  },
);
