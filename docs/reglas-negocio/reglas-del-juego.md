# Reglas de negocio — El juego (Blackjack 21)

Estas son las reglas que la capa `game/domain/` debe implementar. Provienen de la versión web original
(ya probada) y deben preservarse al migrar a Dart. **Si el código difiere de este documento, manda este
documento.**

## Objetivo

Acercarse a 21 puntos sin pasarse, superando la mano del crupier (el sistema). Pasarse de 21 = perder
("se planta" / "bust").

## Valor de las cartas

- Cartas 2–10: su valor numérico.
- J, Q, K: valen 10.
- As: vale 11 o 1, lo que más convenga sin pasarse. Una mano con un As contado como 11 se llama
  **"suave"** (soft).

`calcularPuntos(cartas)` calcula el mejor total posible. `infoMano(cartas)` devuelve `{ total, suave }`.

## Jugadas del jugador

| Jugada | Cuándo es legal | Efecto |
|--------|-----------------|--------|
| **Pedir** (hit) | Siempre, en turno | Recibe una carta |
| **Plantarse** (stand) | Siempre, en turno | Termina su mano |
| **Doblar** (double) | Exactamente 2 cartas, sin haber doblado antes, con saldo ≥ apuesta | Duplica la apuesta, recibe **una** carta y se planta |
| **Dividir** (split) | 2 cartas del mismo valor, no es un As ya partido, < 4 manos abiertas, saldo ≥ apuesta | Separa el par en dos manos, cada una con su apuesta |
| **Rendirse** (surrender) | 2 cartas, una sola mano (sin splits), si `permitirRendirse` está activo | Abandona la mano y recupera la **mitad** de la apuesta |
| **Seguro** (insurance) | Cuando la carta visible del crupier es un As | Apuesta lateral contra el blackjack del crupier |

> **Split de ases:** las manos resultantes de partir ases (`asPartido`) reciben una sola carta y no
> pueden volver a dividirse.

## Reglas del crupier (el sistema)

El crupier juega automáticamente tras los jugadores:

```
debePedirCrupier():
  total, suave = infoMano(cartas del crupier)
  si total < 17                              → pide
  si total == 17 y suave y H17 activo        → pide   (regla "H17")
  en otro caso                               → se planta
```

- **H17** (`crupierPideEn17Suave`): si está activo, el crupier pide con 17 suave (As+6). Si está
  desactivado, se planta en cualquier 17.

## Blackjack natural

- Es un 21 con las **2 primeras cartas**, en una **sola mano** (sin splits) y **sin haber doblado**.
- Paga según `pagoBlackjack`: **3:2** (factor 1.5) o **6:5** (factor 1.2).
- Una mano de 21 lograda tras un split **no** cuenta como blackjack natural (paga normal).

## Resolución de una mano

`resolverMano(mano)` determina el resultado y la ganancia devuelta a la banca:

1. **Rendida** → recupera la mitad de la apuesta (`floor(apuesta / 2)`).
2. **Jugador > 21** → pierde.
3. **Empuje en 22** (`empujeEn22`, variante): si el crupier llega exactamente a 22 → **empate**.
4. **Crupier > 21** → el jugador gana.
5. Si nadie se pasó: gana el total más alto; iguales → empate.

Ganancia devuelta:
- **Ganar con blackjack natural:** `apuesta + floor(apuesta * pagoBlackjack)`.
- **Ganar normal:** `apuesta * 2` (recupera la apuesta + gana otro tanto).
- **Empate:** `apuesta` (se devuelve la apuesta).
- **Perder:** 0.

## Variantes de casa configurables (`ConfigJuego`)

Provienen del `config` original. Valores por defecto entre paréntesis:

| Campo | Defecto | Significado |
|-------|---------|-------------|
| `numBarajas` | 6 | Barajas en el shoe (1–8) |
| `pagoBlackjack` | 1.5 | 3:2 (1.5) o 6:5 (1.2) |
| `crupierPideEn17Suave` | false | H17 |
| `empujeEn22` | false | Crupier 22 = empate |
| `apuestaMin` | 10 | Apuesta mínima |
| `apuestaMax` | 500 | Apuesta máxima |
| `permitirRendirse` | true | Habilita "Rendirse" |
| `modoEntrenamiento` | false | Avisa al desviarse de la estrategia óptima |
| `mostrarConteo` | false | Muestra el conteo Hi-Lo |
| `mostrarProbabilidad` | true | Muestra la probabilidad de pasarse |
| `bancaInicial` | 1000 | Saldo inicial (en multijugador lo gobierna la economía de créditos) |

## El mazo (shoe)

- Se juega con un **shoe** de varias barajas mezcladas.
- Se rebaraja automáticamente al alcanzar cierta penetración (~25% restante).
- Conteo **Hi-Lo** disponible como ayuda (cartas 2–6 = +1; 7–9 = 0; 10/A = −1). El "conteo verdadero"
  divide el corrido entre las barajas restantes.

## Ayudas de aprendizaje (opcionales)

- **Estrategia básica óptima** (`estrategia.dart`): recomienda pedir/plantarse/doblar/dividir/rendirse
  según la mano y la carta visible del crupier.
- **Probabilidad de pasarse**: chance de superar 21 si se pide una carta más.
- **Modo entrenamiento**: avisa cuando la jugada elegida se desvía de la óptima.

## Diferencias en multijugador

- El crupier sigue siendo el sistema; **los jugadores no compiten entre sí**, cada uno juega su mano
  contra el crupier.
- El reparto y la resolución se hacen en **Cloud Functions** (anti-trampa); ver
  [`salas-y-multijugador.md`](salas-y-multijugador.md) y [`../arquitectura/seguridad.md`](../arquitectura/seguridad.md).
