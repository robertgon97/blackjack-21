# Feature: Autenticación, perfil y saldo persistente

## Propósito

Permite que el jugador entre a la app (email/contraseña, Google o modo anónimo demo), tenga un
perfil persistente en Firestore con su saldo de créditos, y consulte su historial de movimientos.
Es la base sobre la que se construyen las features sociales y multijugador (necesitan identidad y
saldo). Corresponde a la **Fase 3** del [plan maestro](../plans/00-app-multiplataforma.md).

## Reglas de negocio

Reglas detalladas en [`../reglas-negocio/creditos-y-economia.md`](../reglas-negocio/creditos-y-economia.md).
Resumen de lo implementado en esta fase:

- **Bono de bienvenida:** al crear el perfil por primera vez se asigna `balance = 1000`. En la Fase 3
  lo escribe el cliente al crear el documento; en la Fase 5+ esa escritura la hará una Cloud Function
  (el cliente no debe poder fijar su saldo).
- **El saldo (`balance`) es de solo lectura para el cliente.** El cliente lo lee por `snapshots()`;
  solo Cloud Functions pueden escribirlo (ver `firestore.rules`).
- **El historial de transacciones es de solo lectura para el cliente.** Cada movimiento queda en la
  sub-colección `transactions` y solo lo escriben las Functions.
- **Código de invitación (`inviteCode`):** se genera al crear el perfil (formato `BJ-XXXX` a partir
  del uid). Lo consumirá la Fase 4 (amigos) y el deep link `/join/CODE`.
- **Modo anónimo:** entra como "Jugador Demo" con el mismo bono; útil para probar sin registrarse.

## Modelo de datos tocado

Ver [`../arquitectura/modelo-datos.md`](../arquitectura/modelo-datos.md).

- **`users/{uid}`** (lectura/creación): `displayName`, `email`, `avatar`, `balance` 🔒,
  `inviteCode`, `isAnonymous`, `createdAt`, `lastSeen`.
- **`users/{uid}/transactions/{txId}`** 🔒 (solo lectura desde el cliente): `type`, `amount`,
  `balance_after`, `description`, `createdAt`, y opcionales `gameId`, `fromUid`, `toUid`.

🔒 = el cliente solo lee; las escrituras las hace Cloud Functions (Fase 5+).

## Estructura del código

```
features/auth/
├── domain/
│   ├── perfil_usuario.dart      ← entidad PerfilUsuario (inmutable, copyWith)
│   └── i_auth_repository.dart   ← interfaz IAuthRepository (sin Firebase)
├── data/
│   └── firebase_auth_repository.dart  ← impl. con Firebase Auth + Firestore + Google
└── presentation/
    ├── auth_provider.dart       ← authRepositoryProvider + perfilStreamProvider
    └── pantalla_login.dart      ← UI de login/registro

features/wallet/
├── domain/
│   ├── transaccion.dart         ← TipoTransaccion (enum) + Transaccion
│   └── i_wallet_repository.dart ← interfaz IWalletRepository (solo lectura)
├── data/
│   └── firestore_wallet_repository.dart  ← lee balance y transactions de Firestore
└── presentation/
    ├── wallet_provider.dart     ← providers de saldo e historial
    └── historial_page.dart      ← lista de movimientos

core/router/
└── app_router.dart              ← go_router con redirect según sesión
```

Archivos y responsabilidades clave:
- `auth/domain/i_auth_repository.dart` — contrato: `perfilStream`, `entrarAnonimo`, `registrar`,
  `entrarConEmail`, `entrarConGoogle`, `salir`. La UI solo conoce esta abstracción.
- `auth/data/firebase_auth_repository.dart` — implementación. Crea/lee `users/{uid}`, genera
  `inviteCode` y asigna el bono inicial si el documento no existe.
- `wallet/domain/i_wallet_repository.dart` — contrato de solo lectura: `saldoStream`,
  `transaccionesStream`.
- `wallet/data/firestore_wallet_repository.dart` — mapea los docs de Firestore a `Transaccion`
  (incluye la traducción `snake_case` ↔ enum: `transfer_in` → `transferIn`, etc.).
- `core/router/app_router.dart` — `redirect`: sin sesión → `/login`; con sesión en `/login` → `/`.
  Se refresca con un `ChangeNotifier` que escucha `perfilStreamProvider`.

## Dependencias externas

- `firebase_auth`, `cloud_firestore`, `google_sign_in` — detrás de `IAuthRepository` /
  `IWalletRepository`, así la presentación y el domain no dependen de Firebase directamente.
- `go_router` — navegación con guard de sesión.
- Requiere `lib/firebase_options.dart` (de `flutterfire configure`) y los proveedores de Auth
  habilitados en la consola Firebase (Email/Password, Google, Anónimo).

## Cloud Functions relacionadas

Ninguna todavía. En la Fase 3 las escrituras de `balance` y `transactions` están bloqueadas por
`firestore.rules` para el cliente, pero aún no hay Functions que las realicen. Llegarán en la
Fase 5 (resolución de partidas) y la Fase 4 (transferencias entre usuarios). Ver
[`../arquitectura/seguridad.md`](../arquitectura/seguridad.md).

## Casos borde

- **Perfil inexistente al iniciar sesión** → `_fetchOCrearPerfil` lo crea con el bono de bienvenida.
- **Login con Google cancelado por el usuario** → lanza excepción; la UI muestra el error sin crear
  sesión.
- **`perfilActual` sincrónico** → devuelve un perfil mínimo con `balance = 0`; el saldo real llega
  por el `snapshots()` de Firestore (no usar el sincrónico para mostrar saldo).
- **Tipo de transacción desconocido en Firestore** → `_parseTipo` cae a `win` por defecto (no rompe
  la lista).

## Cómo probarlo

- **Tests automáticos (`flutter test`):** los repositorios aceptan instancias inyectadas
  (`FirebaseAuth?`, `FirebaseFirestore?`, `GoogleSignIn?`) para poder mockearlos. La cobertura
  automática de esta capa queda pendiente (requiere fakes de Firebase).
- **Prueba manual:**
  1. `flutter run -d chrome` con Firebase configurado.
  2. Entrar en modo anónimo → debe aparecer la pantalla de juego con saldo 1000.
  3. Registrar un email → verificar que se crea `users/{uid}` con `inviteCode` y `balance = 1000`.
  4. Abrir el historial → debe listar las transacciones (vacío al inicio).
  5. Cerrar sesión → el router redirige a `/login`.
