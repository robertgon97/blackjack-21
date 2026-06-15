// ─────────────────────────────────────────────────────────────────────────────
// Evaluación de logros server-side (Fase 9). Anti-trampa: la Function decide
// qué logros se desbloquean al resolver una ronda y los persiste en
// users/{uid}.logros (array de IDs). El cliente solo los lee y muestra.
//
// La METADATA de los logros (nombre, emoji, descripción) vive en el espejo Dart
// lib/features/profile/domain/logros.dart para la galería de la UI. Aquí solo
// están los IDs y sus condiciones. Al añadir/cambiar un logro, actualizar ambos.
// ─────────────────────────────────────────────────────────────────────────────

import { EstadisticasJugador } from './blackjack';

/** Condición de un logro a partir de las stats acumuladas y el saldo actual. */
interface DefinicionLogro {
  id: string;
  /** Nombre legible (para el texto del push); espejo de `logros.dart`. */
  nombre: string;
  cond: (stats: EstadisticasJugador, balance: number) => boolean;
}

const LOGROS: DefinicionLogro[] = [
  { id: 'primera', nombre: '🎉 Primera victoria', cond: (s) => s.ganadas >= 1 },
  { id: 'bj', nombre: '🃏 ¡Blackjack!', cond: (s) => s.blackjacks >= 1 },
  { id: 'racha3', nombre: '🔥 3 seguidas', cond: (s) => s.mejorRacha >= 3 },
  { id: 'racha5', nombre: '🔥🔥 5 seguidas', cond: (s) => s.mejorRacha >= 5 },
  { id: 'veterano', nombre: '🎖️ Veterano', cond: (s) => s.manosJugadas >= 50 },
  { id: 'centenario', nombre: '💯 Centenario', cond: (s) => s.manosJugadas >= 100 },
  { id: 'granGanancia', nombre: '💰 Gran ganancia', cond: (s) => s.mayorGanancia >= 500 },
  { id: 'ricachon', nombre: '💎 Ricachón', cond: (_s, balance) => balance >= 5000 },
];

/** Nombre legible de un logro por su id; el propio id si no se encuentra. */
export function nombreLogro(id: string): string {
  return LOGROS.find((l) => l.id === id)?.nombre ?? id;
}

/**
 * Devuelve los IDs de logros recién desbloqueados (no presentes en
 * `yaDesbloqueados`) según las stats y el saldo. Función pura.
 */
export function evaluarLogros(
  stats: EstadisticasJugador,
  balance: number,
  yaDesbloqueados: string[],
): string[] {
  const previos = new Set(yaDesbloqueados);
  const nuevos: string[] = [];
  for (const l of LOGROS) {
    if (!previos.has(l.id) && l.cond(stats, balance)) {
      nuevos.push(l.id);
    }
  }
  return nuevos;
}
