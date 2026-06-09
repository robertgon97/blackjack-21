# Reglas de negocio — Créditos y economía

Los **créditos** son la moneda virtual del juego (no es dinero real). Se usan para apostar en las
partidas. Todo movimiento de créditos se registra en `users/{uid}/transactions` y **solo Cloud
Functions** pueden modificar el saldo (`balance`). Ver
[`../arquitectura/seguridad.md`](../arquitectura/seguridad.md).

## Fuentes de créditos

| Origen | Monto | Implementación | Límite / condición |
|--------|-------|----------------|--------------------|
| Registro nuevo | **+1,000** | Function `onUserCreate` | Una vez por usuario |
| Demo anónimo → cuenta real | **+500** | Function `claimConversionBonus` | Una vez (`conversionBonusGranted`); ver [`../features/conversion-cuenta.md`](../features/conversion-cuenta.md) |
| Invitación aceptada — invitador | **+500** | Function al aceptar amistad | Por cada amigo nuevo que se registra con su código |
| Invitación aceptada — invitado | **+300** | Function al aceptar amistad | Una vez, al registrarse vía código |
| Ver un anuncio | **+200** | Function `rewardAd` | **Máximo 1 vez por hora** (`lastAdReward`) |
| Ganar una ronda | variable | Function `resolveRound` | Según apuesta y pago (ver reglas del juego) |
| Recibir transferencia | variable | Function `transferCredits` | Según lo que envíe el amigo |

## Salidas de créditos

| Motivo | Efecto |
|--------|--------|
| Perder una ronda | Se descuenta la apuesta |
| Enviar transferencia a un amigo | Se descuenta el monto enviado |

## Reglas de las transferencias

- El **monto debe ser > 0** y el emisor debe tener **saldo suficiente**.
- **No** se permite auto-transferencia (enviarse a uno mismo).
- Ambos usuarios deben existir; idealmente, ser amigos aceptados.
- **Rate-limit:** máximo **10 transferencias por hora** por usuario.
- La operación es **atómica** (transacción de Firestore): o se completan ambos lados (débito + crédito)
  o ninguno. Se escriben dos transacciones: `transfer_out` (emisor) y `transfer_in` (receptor).

## Reglas de los anuncios

- Botón "Ver anuncio → +200 créditos", disponible **una vez por hora**.
- La Function `rewardAd` valida que `lastAdReward` sea de hace más de 1 hora antes de acreditar.
- En lo posible, validar también el callback del proveedor de anuncios (AdMob/AdSense) para confirmar
  que el anuncio se vio de verdad.

## Anti-bancarrota

- Si un jugador se queda sin créditos, puede recuperarse viendo anuncios, recibiendo transferencias de
  amigos, o (a definir) un bono diario / préstamo limitado.
- La versión original daba un "préstamo" de emergencia al llegar a 0; en la app esto se reemplaza por
  las fuentes de arriba para evitar inflación descontrolada. **Decisión pendiente:** si se mantiene un
  bono diario, definir monto y cooldown aquí.

## Historial de movimientos

Cada cambio de saldo crea un documento en `users/{uid}/transactions` con: tipo, monto, saldo resultante
(`balance_after`), descripción legible y fecha. La pantalla de historial (feature `wallet`) lista estos
movimientos en orden cronológico inverso.

## Notas de balance económico

- Los montos de los bonos son un punto de partida; se pueden ajustar para mantener la economía sana
  (evitar que sea trivial acumular créditos infinitos). Cualquier ajuste se documenta aquí.
- Considerar topes de saldo o "sumideros" de créditos (cosméticos, mesas premium) en fases futuras si
  la inflación se vuelve un problema.
