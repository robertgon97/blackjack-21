# Feature: Social — Amigos y transferencias

## Propósito

Permite que los jugadores se agreguen como amigos mediante un **código de invitación** único,
gestionen solicitudes de amistad y se **transfieran créditos** entre sí de forma atómica. Es la base
del sistema social que en Fase 5 se usará para invitar a partidas multijugador.
Corresponde a la **Fase 4** del [plan maestro](../plans/00-app-multiplataforma.md).

## Reglas de negocio

Reglas detalladas en [`../reglas-negocio/social.md`](../reglas-negocio/social.md) y
[`../reglas-negocio/creditos-y-economia.md`](../reglas-negocio/creditos-y-economia.md). Resumen:

### Amistades
- Cada usuario tiene un `inviteCode` único (ej. `BJ-AB12`), generado al crear la cuenta.
- Modelo bilateral: `friendships/{uid}/contacts/{friendUid}` con `status: pending | accepted`.
  Se escribe en **ambos lados** desde el cliente (batch write) gracias a las reglas de Firestore.
- No se puede enviar solicitud a uno mismo.
- Cualquiera de los dos puede eliminar la amistad (borra ambos lados).
- Un usuario pendiente o aceptado no duplica solicitudes (la existencia del doc lo evita en la UI).

### Transferencias
- Solo entre usuarios existentes; idealmente amigos aceptados.
- Monto > 0, entero, y con saldo suficiente; sin auto-transferencia.
- Rate limit: máximo **10 transferencias por hora** por usuario.
- Operación atómica vía Cloud Function `transferCredits` (Firestore transaction): débito del emisor
  + crédito del receptor + dos registros en `transactions`.

## Modelo de datos tocado

Ver [`../arquitectura/modelo-datos.md`](../arquitectura/modelo-datos.md).

- **`invite_codes/{inviteCode}`** (nuevo): `{ uid, displayName, avatar }` — lookup-table de
  códigos, readable por cualquier usuario autenticado.
- **`friendships/{uid}/contacts/{friendUid}`**: `{ status, initiatedBy, since, displayName, avatar }`
  — relación bilateral. El campo `displayName`/`avatar` almacena la info del **otro** usuario
  (desnormalización para evitar N lecturas).
- **`users/{uid}/transactions/{txId}`** 🔒: escrito por `transferCredits` (Cloud Function) con
  `type: transfer_out | transfer_in`.

## Estructura del código

```
features/friends/
├── domain/
│   ├── contacto.dart              ← Contacto (entidad) + EstadoAmistad (enum)
│   ├── resultado_busqueda.dart    ← DTO mínimo de búsqueda por código
│   └── i_friends_repository.dart ← contrato (sin Firebase)
├── data/
│   └── firestore_friends_repository.dart  ← impl. con Firestore + FirebaseFunctions
└── presentation/
    ├── friends_provider.dart      ← friendsRepositoryProvider + contactosProvider
    ├── friends_page.dart          ← lista de amigos, solicitudes y diálogo de búsqueda
    └── transfer_page.dart         ← formulario de transferencia con confirmación

functions/src/
├── index.ts                       ← inicialización de Firebase Admin + re-exports
└── transfers.ts                   ← transferCredits (onCall, v2, southamerica-east1)
```

Archivos y responsabilidades clave:
- `domain/i_friends_repository.dart` — contrato: `contactosStream`, `buscarPorCodigo`,
  `enviarSolicitud`, `aceptarSolicitud`, `eliminarContacto`, `transferirCreditos`.
- `data/firestore_friends_repository.dart` — `buscarPorCodigo` lee `invite_codes/{code}`;
  `enviarSolicitud` hace batch write bilateral; `transferirCreditos` llama a la Cloud Function.
- `presentation/friends_page.dart` — dos tabs (Amigos / Solicitudes), header con código copiable,
  diálogo de búsqueda con flujo buscar → confirmar → enviar solicitud.
- `presentation/transfer_page.dart` — formulario con validación de saldo, diálogo de confirmación
  y manejo de `FirebaseFunctionsException` con mensajes en español.
- `functions/src/transfers.ts` — valida auth, no-auto-transferencia, monto positivo, rate limit
  (count de `transfer_out` en la última hora), y ejecuta transacción atómica Firestore.

## Dependencias externas

- `cloud_functions: ^5.1.0` — llamada a `transferCredits` desde Flutter.
- Firebase Auth (ya en Fase 3) — contexto de autenticación para las reglas.
- Firestore rules actualizadas en `firestore.rules` (Fase 4):
  - Nueva colección `invite_codes`.
  - `friendships` extendido para batch writes bilaterales sin Cloud Function.
  - `esAmigoDe()` corregida para verificar `status == 'accepted'` (no solo existencia).
  - `users.create` permitido temporalmente desde el cliente (workaround hasta `onUserCreate`).

## Cloud Functions relacionadas

| Function | Tipo | Región | Estado |
|----------|------|--------|--------|
| `transferCredits` | onCall (v2) | southamerica-east1 | ⬜ Pendiente despliegue (requiere Blaze) |

Ver [`../arquitectura/seguridad.md`](../arquitectura/seguridad.md) para el modelo de seguridad.

## Casos borde

- **Código propio en búsqueda** → la UI detecta `res.uid == myUid` y muestra error antes de enviar.
- **Código inexistente** → `buscarPorCodigo` retorna `null`; se muestra mensaje de no encontrado.
- **Solicitud duplicada** → si ya existe el doc, el batch falla en Firestore (write sobre doc
  existente cuando `create` no aplica); la UI debe capturarlo y mostrar "ya hay solicitud".
- **Saldo insuficiente en transferencia** → la Function lanza `failed-precondition`; la UI muestra
  mensaje localizado.
- **Rate limit** → `resource-exhausted`; la UI muestra el límite de 10/hora.
- **Function no desplegada** → `functions/not-found`; la UI muestra error genérico. Se espera hasta
  que el plan Blaze esté activo y se ejecute `firebase deploy --only functions`.

## Cómo probarlo

- **Tests automáticos:** la capa domain no tiene dependencias externas y no requiere tests
  adicionales en esta fase. Los repositorios aceptan instancias inyectadas para mockear en el futuro.
- **Prueba manual (Firestore en producción o emulador):**
  1. Usuario A inicia sesión → verifica que `invite_codes/{A.inviteCode}` existe en Firestore.
  2. Usuario B inicia sesión en otro dispositivo/pestaña → busca el código de A → envía solicitud.
  3. A ve la solicitud en la tab "Solicitudes" → acepta → ambos pasan a "Amigos".
  4. B navega a `/friends/transfer` con A como destino → ingresa monto → confirma.
  5. Verificar en Firestore que `balance` de A aumentó y el de B disminuyó, y que hay registros
     en `transactions` de ambos (`transfer_in`/`transfer_out`).
     ⚠️ Paso 4-5 requiere Cloud Function desplegada (plan Blaze).
