# Feature: Conversión de cuenta anónima a permanente

> **Estado: DISEÑO — pendiente de implementar.** Esta ficha describe el diseño aprobado; el código
> aún no existe. Corresponde a la **Fase 3.5** del [plan maestro](../plans/00-app-multiplataforma.md)
> (mejora de la Fase 3 de auth). Al implementarla, quitar este aviso y marcar lo realmente hecho.

## Propósito

Hoy un jugador puede entrar en **modo demo anónimo** ("Jugar sin registrarse"), acumular saldo,
código de invitación, amigos e historial… pero **no tiene ninguna forma de registrarse después**: el
`redirect` del router manda siempre a `/` cuando hay sesión y nunca deja volver a `/login`. Si el
usuario quiere una cuenta real, el único camino actual sería cerrar sesión —y una cuenta anónima de
Firebase **no se puede recuperar**, así que perdería todo su progreso.

Esta feature cierra ese hueco con **vinculación de credenciales (account linking)** de Firebase Auth:
convierte la cuenta anónima en permanente (email/contraseña o Google) **conservando el mismo `uid`**,
de modo que saldo, `inviteCode`, amigos y transacciones se mantienen intactos. Además **incita** al
jugador anónimo a convertirse en los momentos adecuados, y le otorga un **bono de +500 créditos** la
primera vez que lo hace.

## Reglas de negocio

Reglas de créditos detalladas en
[`../reglas-negocio/creditos-y-economia.md`](../reglas-negocio/creditos-y-economia.md).

- **El `uid` se conserva.** La conversión usa `linkWithCredential` sobre el usuario anónimo actual; no
  crea un usuario nuevo. Todo lo que cuelga de `users/{uid}` (saldo, amigos, historial) sigue siendo
  del mismo dueño.
- **Bono de conversión: +500 créditos, una sola vez.** Lo acredita una Cloud Function
  (`claimConversionBonus`), nunca el cliente (el cliente no puede escribir `balance`). Es **idempotente**:
  se protege con el flag `conversionBonusGranted` en `users/{uid}` para no pagar dos veces aunque el
  cliente reintente.
- **Email único.** No se puede vincular un email/Google que **ya pertenece a otra cuenta**. En ese caso
  no hay merge automático (fusionar dos cuentas con saldos distintos es complejo); se ofrece al usuario
  iniciar sesión en la cuenta existente, **advirtiendo que perderá el progreso del demo**.
- **Incitación, no obligación.** El modo demo sigue siendo plenamente jugable. La invitación a
  registrarse es persistente pero **descartable**; nunca bloquea el juego.
- **`isAnonymous` pasa a `false`** tras una conversión exitosa. La fuente de verdad es el proveedor del
  token de Firebase Auth (`sign_in_provider`); el campo en Firestore es una copia que actualiza la
  Function al dar el bono.

## Casos de uso / Flujo

### CU-1 · Convertir con email (camino feliz)

1. El jugador anónimo toca el banner "Crea tu cuenta para no perder tu progreso" o el botón de la barra.
2. Navega a `/convertir` (accesible **con** sesión; el router no lo redirige porque `perfil != null`).
3. Rellena email + contraseña (el nombre ya lo tiene del demo; editable).
4. `vincularConEmail` → `currentUser.linkWithCredential(EmailAuthProvider.credential(...))`.
5. Firebase actualiza el mismo usuario: `isAnonymous` del token pasa a `false`, mismo `uid`.
   **Importante:** el ID token en caché no se refresca de forma síncrona. Antes del paso 6 hay que
   llamar `await user.getIdToken(true)` para que el token enviado a la Function ya no sea anónimo;
   sin este refresh, la Function rechazará la llamada aunque la vinculación haya sido exitosa.
6. El cliente invoca la Function `claimConversionBonus`; ésta valida y acredita +500, marca
   `conversionBonusGranted: true`, pone `isAnonymous: false` y escribe una transacción
   `bonus_conversion`.
7. Toast de éxito: "¡Cuenta creada! +500 créditos de regalo." El `perfilStream` refleja el nuevo estado.

### CU-2 · Convertir con Google

Igual que CU-1 pero con `linkWithCredential(GoogleAuthProvider.credential(...))` (o `linkWithPopup` en
web). Tras vincular, `firebase_auth_repository.dart` **actualiza explícitamente** el doc de Firestore
`users/{uid}` con `displayName` y `avatar` del `UserCredential` devuelto (los valores de la cuenta de
Google), usando `user.displayName` y `user.photoURL`. `linkWithCredential` actualiza Firebase Auth pero
**no** el doc de Firestore; sin este paso el demo conserva el nombre del demo indefinidamente.

### CU-3 · El email/Google ya pertenece a otra cuenta

- Firebase lanza `credential-already-in-use` (Google/OAuth) o `email-already-in-use` (email+contraseña).
  Son errores distintos: en `credential-already-in-use` el objeto error incluye `error.credential`
  (recuperable para hacer `signInWithCredential` directo); en `email-already-in-use` no hay credential
  adjunta y el usuario debe hacer `signInWithEmailAndPassword` con su contraseña.
- Se muestra un diálogo: *"Ese email ya tiene una cuenta. Puedes iniciar sesión en ella, pero perderás
  el progreso de esta sesión de demo (saldo, amigos)."* con botones **Iniciar sesión** / **Cancelar**.
- Si acepta: se cierra la sesión anónima y se entra a la cuenta existente (su saldo real). El demo se
  descarta. (El **merge** de dos cuentas queda como mejora futura, fuera de alcance.)

### CU-4 · Conversión con la red caída / reintento

- Si la vinculación de Firebase Auth falla por red, no se creó nada: el usuario sigue anónimo y puede
  reintentar.
- Si la vinculación tuvo éxito pero `claimConversionBonus` falló (timeout), al reintentar la Function es
  **idempotente**: ve `conversionBonusGranted == true`… o, si nunca llegó a marcarlo, lo hace ahora —
  pero **nunca** acredita dos veces. El cliente puede reintentar el cobro sin riesgo.

### CU-5 · Cerrar sesión siendo anónimo

- Si un usuario anónimo intenta **Cerrar sesión**, se muestra una advertencia: *"Tu cuenta demo no se
  puede recuperar. Si cierras sesión perderás tu saldo y tus amigos. ¿Crear una cuenta primero?"* con
  botones **Crear cuenta** / **Cerrar de todos modos** / **Cancelar**.

### CU-6 · ¿Cuándo se incita a convertir? (incitación pasiva y contextual)

- **Pasiva:** un banner descartable en la pantalla de juego mientras `perfil.isAnonymous == true`.
- **Contextual (momentos de alto valor):** al ganar una banca grande, al superar cierto saldo, o al
  intentar usar una feature social (agregar amigo / transferir) que gana sentido con identidad
  permanente. En esos puntos se muestra un modal suave con el CTA de conversión.

## Modelo de datos tocado

Ver [`../arquitectura/modelo-datos.md`](../arquitectura/modelo-datos.md). Cambios:

- **`users/{uid}`** — nuevo campo `conversionBonusGranted` (bool, 🔒 solo Functions). Al convertir,
  la Function pone `isAnonymous: false`, suma 500 a `balance` 🔒 y marca `conversionBonusGranted: true`.
- **`users/{uid}/transactions/{txId}`** — nuevo `type`: `bonus_conversion` (monto 500).

## Estructura del código (propuesta)

```
features/auth/
├── domain/
│   └── i_auth_repository.dart   ← + vincularConEmail(...) y vincularConGoogle()
├── data/
│   └── firebase_auth_repository.dart  ← link* + llamada a claimConversionBonus;
│                                         mapea FirebaseAuthException a mensajes (en data, no en UI)
└── presentation/
    ├── auth_provider.dart       ← (sin cambios mayores; el estado de conversión sale de perfilStream)
    ├── pantalla_conversion.dart ← formulario de conversión (reutiliza la UI de PantallaLogin en "modo convertir")
    └── widgets/
        └── banner_conversion.dart  ← CTA descartable mostrado si perfil.isAnonymous

core/router/
└── app_router.dart              ← + ruta '/convertir' (accesible con sesión; sin redirect)

functions/src/
└── conversion.ts                ← claimConversionBonus (callable, idempotente) — re-export en index.ts
```

Responsabilidades clave:
- `i_auth_repository.dart` — añade `vincularConEmail({email, password})` y `vincularConGoogle()`. La UI
  solo conoce esta abstracción.
- `firebase_auth_repository.dart` — implementa con `currentUser.linkWithCredential(...)` /
  `linkWithPopup`; tras vincular:
  1. `await user.getIdToken(true)` — refresco obligatorio del token antes de invocar la Function
     (sin él el token en caché sigue siendo anónimo y la Function rechaza la llamada).
  2. Llama a `claimConversionBonus`.
  3. En CU-2 (Google), actualiza `displayName` y `avatar` en Firestore con los valores de
     `userCredential.user.displayName` / `photoURL`.
  **Atrapa `FirebaseAuthException` en la capa data** y lanza un `Exception` con mensaje en español
  (lección de la Fase 4 — ver `docs/errores-y-correcciones.md`). Distinguir `credential-already-in-use`
  (incluye `error.credential` recuperable para `signInWithCredential`) de `email-already-in-use` (no la
  incluye; el usuario debe hacer `signInWithEmailAndPassword` manualmente) — ver CU-3.
- `_fromDoc` en `firebase_auth_repository.dart` — usar **`user.isAnonymous` del token Auth** como
  fuente de verdad, no el campo Firestore (`d['isAnonymous']`). El campo Firestore se actualiza
  al final de `claimConversionBonus`; si `_fromDoc` lee Firestore primero, `perfilStream` emite
  `isAnonymous: true` durante la ventana post-`linkWithCredential` / pre-Function y el banner de
  conversión reaparece brevemente. Patrón correcto: `isAnonymous: user.isAnonymous`.
- `pantalla_conversion.dart` — formulario (email, contraseña, nombre editable) + botón Google.
- `banner_conversion.dart` — invitación descartable; se oculta si la cuenta ya es permanente.
- `app_router.dart` — la ruta `/convertir` es alcanzable **mientras hay sesión**; el `redirect` actual
  solo expulsa de `/login`, así que esta ruta no se ve afectada.

## Dependencias externas

- `firebase_auth` (ya presente) — `linkWithCredential`, `linkWithPopup`, `EmailAuthProvider`,
  `GoogleAuthProvider`. Detrás de `IAuthRepository`.
- `google_sign_in` (ya presente) — para obtener la credencial de Google a vincular.
- `cloud_functions` (ya presente desde Fase 4) — para invocar `claimConversionBonus`.

No añade paquetes nuevos al `pubspec.yaml`.

## Cloud Functions relacionadas

Ver [`../arquitectura/seguridad.md`](../arquitectura/seguridad.md).

- **`claimConversionBonus`** (callable, región `southamerica-east1`):
  - Valida `request.auth` y que el token **ya no sea anónimo**
    (`request.auth.token.firebase.sign_in_provider != 'anonymous'`) — impide cobrar antes de convertir.
  - Lee `users/{uid}` en Firestore; aplica tres guardas antes de acreditar:
    1. `isAnonymous == true` en el doc — confirma que la cuenta **fue** anónima antes de la conversión.
       Sin esta guarda, cualquier cuenta permanente sin el flag (incluidas todas las preexistentes)
       podría llamar la Function y recibir +500 gratis, ya que `conversionBonusGranted` no existe en
       su doc y `sign_in_provider` ya es no-anónimo.
    2. `conversionBonusGranted != true` — idempotencia; si ya se pagó, no se vuelve a acreditar.
    3. (implícita) La transacción escribe de forma atómica: `balance += 500`,
       `conversionBonusGranted = true`, `isAnonymous = false`, y la tx `bonus_conversion`.

> Nota: el trigger `onUserCreate` (bono de registro) **no** se dispara al vincular (el usuario ya
> existía), por eso hace falta este callable dedicado en vez de reutilizar aquél.

## Casos borde

- **`provider-already-linked` / `credential-already-in-use`** → CU-3 (ofrecer iniciar sesión en la
  cuenta existente; advertir pérdida del demo).
- **`email-already-in-use`** → mismo tratamiento que CU-3.
- **`requires-recent-login`** → **fallo terminal** para cuentas anónimas. Re-autenticar no es viable:
  no hay credenciales y `signInAnonymously()` crearía un `uid` nuevo, descartando todo el progreso.
  La implementación debe tratar este error como terminal y mostrar: *"La sesión ha expirado y no se
  puede conservar tu progreso. Cierra sesión e inicia de nuevo."* — nunca como un reintento silencioso.
- **Vinculación OK pero el bono falla** → CU-4 (idempotencia; el cliente puede reintentar el cobro).
- **Usuario ya permanente entra a `/convertir`** → el banner no se muestra y la pantalla informa que la
  cuenta ya está registrada.
- **Cerrar sesión siendo anónimo** → CU-5 (advertencia de pérdida irreversible).

## Cómo probarlo

- **Tests automáticos (`flutter test`):** los repos aceptan `FirebaseAuth?`/`FirebaseFirestore?`
  inyectados para mockear el flujo de vinculación. La Function `claimConversionBonus` se cubre con su
  idempotencia (segundo llamado no acredita de nuevo).
- **Prueba manual:**
  1. `flutter run -d chrome`, entrar en **modo demo** → jugar hasta tener un saldo ≠ 1000.
  2. Tocar el banner → `/convertir` → registrar email → verificar: **mismo saldo + 500**, mismo
     `inviteCode`, `isAnonymous == false`, y una transacción `bonus_conversion` en el historial.
  3. Repetir el cobro del bono (forzar reintento) → el saldo **no** cambia (idempotencia).
  4. Intentar convertir con un email ya registrado → debe aparecer el diálogo de CU-3.
  5. Como anónimo, intentar **Cerrar sesión** → debe aparecer la advertencia de CU-5.
