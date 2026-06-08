# Reglas de negocio — Social (amigos, invitaciones, transferencias)

El sistema social conecta jugadores para que se inviten a partidas y se pasen créditos.

## Código de invitación

- Cada usuario tiene un `inviteCode` **único** (ej. `ROB-X4K2`), generado al crear la cuenta.
- Sirve para dos cosas:
  1. **Buscar y agregar amigos** por código.
  2. **Compartir un enlace de registro/invitación** que da bonos a ambos (ver
     [`creditos-y-economia.md`](creditos-y-economia.md)).

## Amistades

Modelo: `friendships/{uid}/contacts/{friendUid}` con `status: pending | accepted`. Se guarda en **ambos
lados** para listar amigos de cada quien con una sola consulta.

Flujo:
1. **A** envía solicitud a **B** (por código o nombre) → se crea `pending` en ambos, con
   `initiatedBy: A`.
2. **B** acepta → ambos pasan a `accepted`. (O rechaza → se borran ambos.)
3. Ya amigos, pueden: verse en línea, invitarse a salas y transferirse créditos.

Reglas:
- No duplicar solicitudes (si ya existe `pending` o `accepted`, no crear otra).
- No agregarse a uno mismo.
- Cualquiera de los dos puede **eliminar** la amistad (borra ambos lados).

## Invitaciones a partida

- Desde una sala, un jugador comparte el link `/join/CODE`.
- Si el destinatario tiene la app, el deep link lo lleva directo a la sala; en web, abre la URL.
- Opcional (fase de pulido): notificación push "Tu amigo te invita a una partida" vía
  `firebase_messaging`.

## Transferencias de créditos

Reglas detalladas en [`creditos-y-economia.md`](creditos-y-economia.md). Resumen:
- Solo entre usuarios existentes (idealmente amigos).
- Monto > 0 y saldo suficiente; sin auto-transferencia.
- Rate-limit de 10/hora por usuario.
- Operación atómica vía Function `transferCredits`; deja rastro en el historial de ambos.

## Presencia (en línea)

- `users/{uid}.lastSeen` se actualiza periódicamente; un usuario se considera "en línea" si su
  `lastSeen` es reciente.
- El listado de amigos muestra quién está en línea para facilitar invitar a jugar.

## Privacidad

- Un usuario solo puede leer el perfil de sus **amigos aceptados** (además del suyo) — ver Rules en
  [`../arquitectura/seguridad.md`](../arquitectura/seguridad.md).
- El `inviteCode` es compartible por el dueño; no expone datos sensibles.
