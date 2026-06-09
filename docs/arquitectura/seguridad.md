# Arquitectura — Seguridad

La seguridad se apoya en dos capas que se complementan: **Firestore Security Rules** (qué puede
leer/escribir cada cliente) y **Cloud Functions** (operaciones sensibles ejecutadas en el servidor con
privilegios de admin).

## Principio rector

> **El cliente nunca mueve dinero ni reparte cartas.** Todo lo que afecta saldo o el resultado de una
> partida pasa por Cloud Functions. Las Rules impiden que el cliente escriba esos campos directamente.

## Firestore Security Rules

| Colección | Lectura | Escritura |
|-----------|---------|-----------|
| `users/{uid}` | El dueño + sus amigos aceptados | El dueño, **excepto `balance`, `lastAdReward`, `conversionBonusGranted` e `isAnonymous`** (solo Functions) |
| `users/{uid}/transactions` | Solo el dueño | **Bloqueada** al cliente (solo Functions) |
| `friendships/{uid}/contacts` | El dueño | El dueño (crear solicitud) y la Function que confirma |
| `rooms/{roomId}` | Pública si `!private`; si no, solo miembros | Host y jugadores del room (campos permitidos) |
| `rooms/{roomId}/chat` | Miembros del room | Miembros del room (su propio `uid`) |
| `games/{gameId}` | Jugadores del room | **Bloqueada** al cliente (solo Functions) |

Reglas finas a implementar:
- En `users`, validar que la escritura **no** modifique `balance`/`lastAdReward` (comparar contra el
  documento previo).
- En `rooms`, un jugador solo puede modificar **su** entrada dentro de `players` (su `ready`,
  `micActivo`, `camActiva`), no la de otros.
- En `chat`, el `uid` del mensaje debe coincidir con `request.auth.uid`.

## Cloud Functions — operaciones sensibles y validaciones

Todas usan el Admin SDK (saltan las Rules) y validan en servidor:

| Function | Qué hace | Validaciones |
|----------|----------|--------------|
| `onUserCreate` (trigger) | Crea el doc de `users` y da el bono de registro | Solo se dispara una vez por usuario; escribe `isAnonymous: sign_in_provider == 'anonymous'` en el doc inicial (necesario para la guarda de `claimConversionBonus`) |
| `claimConversionBonus` | Da el bono de +500 al convertir cuenta anónima → permanente | El token ya **no** es anónimo (`sign_in_provider != 'anonymous'`); dentro de `runTransaction`: (1) `conversionBonusGranted != true` — idempotencia, primero para que los reintentos post-pago sean no-op; (2) `isAnonymous == true` en el doc — confirma origen anónimo (sin esto cuentas permanentes preexistentes podrían cobrar); escritura atómica de `balance += 500`, `conversionBonusGranted = true`, `isAnonymous = false` y tx `bonus_conversion` |
| `transferCredits` | Mueve créditos entre dos usuarios | Saldo suficiente; no auto-transferencia; ambos existen; **rate-limit 10/hora/uid**; monto > 0; transacción atómica (Firestore transaction) |
| `rewardAd` | Acredita créditos por ver un anuncio | `lastAdReward` debe ser > 1 hora antes; idealmente verificar el callback del proveedor de anuncios |
| `startRound` | Genera el shoe y reparte | Solicitante es host; la sala está en fase `betting`; hay jugadores listos |
| `resolveRound` | Calcula resultados y paga | El juego está en fase `dealer` terminada; idempotente (no pagar dos veces) |
| `livekitToken` | Genera token de acceso a la sala de voz/video | El solicitante es miembro del room; el token caduca; claves nunca en el cliente |

## Manejo de secretos

- Claves de LiveKit, AdMob, etc. se guardan en la configuración de Functions
  (`firebase functions:config` o variables de entorno del runtime), **nunca** en el código del cliente
  ni en el repo.
- `firebase_options.dart` (claves públicas de Firebase) sí va en el cliente: son identificadores
  públicos, no secretos. La seguridad real la dan las Rules y las Functions.

## Anti-trampa en el juego

- El `shoe` vive en `games/{id}` con escritura solo-Functions y **no se expone** al cliente; la UI solo
  recibe las cartas ya repartidas y las visibles del crupier.
- El turno del crupier y la resolución se calculan en servidor: un cliente no puede inventar un
  resultado favorable porque no escribe en `games` ni en `balance`.

## Rate-limiting y abuso

- Transferencias: límite por hora y por usuario.
- Anuncios: throttle por `lastAdReward`.
- Considerar App Check (Firebase) en fases posteriores para bloquear clientes no legítimos.
