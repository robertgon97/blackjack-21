# Arquitectura — Visión general

## Idea central: capas + feature-first

El código se organiza por **features** (funcionalidades), y dentro de cada una por **capas**. Esto
mantiene la lógica del juego aislada de Firebase y de la UI, lo que la hace fácil de leer, testear y
cambiar.

```
features/<nombre>/
├── domain/         ← Lógica y modelos puros. NO importa Flutter ni Firebase.
├── data/           ← Repositorios: hablan con Firebase / servicios externos.
└── presentation/   ← Widgets + providers de Riverpod (el estado de la UI).
```

### Regla de dependencias (en una sola dirección)

```
presentation  ──►  domain  ◄──  data
```

- `domain` **no depende de nadie** (ni de Flutter, ni de Firebase, ni de otras features).
- `data` implementa interfaces declaradas en `domain` (patrón repositorio).
- `presentation` usa `domain` (modelos, casos de uso) y consume `data` a través de providers.

> **Por qué importa:** la lógica del Blackjack (calcular puntos, resolver manos, estrategia básica)
> vive en `game/domain/` como funciones puras. Se puede testear sin Firebase ni UI, y es la misma
> lógica que ya estaba probada en la versión web.

## Abstracción de proveedores externos

Todo servicio externo (voz/video, anuncios, push) se accede mediante una **interface en `domain`**, con
la implementación concreta en `data`. Cambiar de proveedor = escribir una clase nueva con la misma
interface, sin tocar la UI.

Ejemplo (comunicación en sala):

```
comms/domain/servicio_comunicacion.dart   ← interface: entrarSala, salir, alternarMicro, alternarCamara
comms/data/livekit_comunicacion.dart      ← implementación actual (LiveKit)
                                             para migrar a Agora/WebRTC → nueva clase, misma interface
```

## Estructura de carpetas

```
lib/
├── main.dart                ← arranque (inicializa Firebase, monta la app)
├── app.dart                 ← MaterialApp.router, tema activo
├── firebase_options.dart    ← generado por `flutterfire configure`
│
├── core/                    ← transversal, sin depender de ninguna feature
│   ├── theme/               ← los 4 temas (Clásico/Noche/Rubí/Oscuro)
│   ├── router/              ← go_router + deep links
│   ├── widgets/             ← widgets compartidos (Toast, AppModal, Avatar)
│   └── utils/               ← helpers puros (formato de dinero, fechas)
│
└── features/
    ├── auth/        (login, registro, sesión)
    ├── game/        (lógica + UI del Blackjack)
    ├── wallet/      (saldo, transacciones, historial)
    ├── friends/     (amigos, invitaciones, transferencias)
    ├── rooms/       (salas multijugador)
    ├── comms/       (chat + voz + cámara)
    └── profile/     (perfil, stats, niveles, logros, leaderboard)
```

## Estado con Riverpod

- El estado se expone con **providers** (`Provider`, `StreamProvider`, `NotifierProvider`).
- Los datos en tiempo real de Firestore se exponen como `StreamProvider` envolviendo `snapshots()`.
- Los modelos son **inmutables** (`freezed`): el estado se reemplaza, nunca se muta en sitio.

## Flujo de datos (ejemplo: saldo del usuario)

```
Firestore users/{uid}.balance
   │  snapshots()
   ▼
balance_repository (data)
   │  Stream<int>
   ▼
saldoProvider (StreamProvider, presentation)
   │  watch
   ▼
Widget que muestra el saldo  ──► se redibuja solo cuando cambia
```

El cliente **nunca** escribe `balance` directamente: las operaciones de dinero pasan por Cloud
Functions (ver [`seguridad.md`](seguridad.md)).

## Convenciones

- Nombres, comentarios y documentación en **español** (con acentos correctos).
- Doc-comment `///` en cada clase y función pública.
- Un archivo = una responsabilidad clara. Si crece demasiado, se divide.
- Linter estricto (`analysis_options.yaml`); el CI falla si `dart format` o `flutter analyze` no pasan.
