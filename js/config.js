// ============================================================
//  CONFIGURACIÓN DE REGLAS DE LA MESA
//  Estos valores se pueden cambiar desde el panel de Ajustes.
//  Al ser un objeto global, el resto de módulos lo leen directamente.
// ============================================================
const config = {
  numBarajas: 6,              // Cuántas barajas hay en el "shoe" (zapato)
  pagoBlackjack: 1.5,         // 3:2 = 1.5 ; 6:5 = 1.2
  crupierPideEn17Suave: false, // H17: el crupier pide con 17 "suave" (As+6)
  empujeEn22: false,          // Variante: si el crupier llega a 22, es EMPATE
  apuestaMin: 10,             // Apuesta mínima permitida
  apuestaMax: 500,            // Apuesta máxima permitida
  permitirRendirse: true,     // Permitir la jugada "Rendirse"
  modoEntrenamiento: false,   // Avisa cuando te desvías de la estrategia óptima
  mostrarConteo: false,       // Muestra el conteo Hi-Lo (cartas)
  mostrarProbabilidad: true,  // Muestra la probabilidad de pasarse
  bancaInicial: 1000,         // Dinero con el que empiezas
};
