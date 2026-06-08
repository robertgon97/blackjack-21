# Flutter — Recursos y recomendaciones oficiales

> Revisado de https://docs.flutter.dev/resources y páginas vinculadas.
> Aplica directamente a este proyecto. Actualizar cuando cambien las versiones del toolkit.

---

## 1. Games Toolkit oficial

Flutter mantiene un toolkit gratuito y open-source en `https://github.com/flutter/games`
con tres plantillas. La más relevante para nosotros:

### Card Game Template (`templates/card/`)

Incluye sobre la base del juego:

| Feature | Incluido |
|---------|----------|
| Menú principal, navegación, settings | ✅ |
| Gestión del progreso del jugador | ✅ |
| Sonidos | ✅ |
| Temas | ✅ |
| **Drag & drop** | ✅ |
| **Hooks de multijugador** | ✅ |
| **Gestión de estado de partida** | ✅ |

> **Nota:** El template usa `provider`. En este proyecto usamos **Riverpod** (evolución type-safe
> de `provider`), que cumple exactamente los mismos roles. No es un conflicto.

El template sirve como **referencia de arquitectura de pantalla**, no como base del código —
ya tenemos nuestra propia capa `domain` con 32 tests pasando.

---

## 2. Multijugador con Cloud Firestore

Fuente: https://docs.flutter.dev/cookbook/games/firestore-multiplayer

### ¿Cuándo usar Firestore vs. Nakama?

| Tipo de juego | Solución recomendada |
|---------------|---------------------|
| **Bajo tick rate** (turnos, cartas, puzzles) | **Cloud Firestore** ← nosotros |
| Alto tick rate (acción, shooters, racing) | Nakama (servidor dedicado) |

Blackjack es bajo tick rate: el estado solo cambia cuando un jugador actúa.
**Firestore es la solución correcta y oficial para este proyecto.**

### Patrón FirestoreController

Flutter documenta una clase `FirestoreController` que sincroniza en ambas direcciones:

```
Estado local (Riverpod/ChangeNotifier)
    ↑ Remoto → Local                ↓ Local → Remoto
Cloud Firestore  ←────────────────→  Cloud Firestore
```

**Código de referencia (del cookbook oficial):**

```dart
class FirestoreController {
  final FirebaseFirestore instance;
  final GameState gameState;
  StreamSubscription? _remoteSub, _localSub;

  // Referencia con tipo fuerte (withConverter)
  late final DocumentReference<EstadoPartida> _ref =
    instance.collection('games').doc(gameId)
      .withConverter<EstadoPartida>(
        fromFirestore: (snap, _) => EstadoPartida.fromJson(snap.data()!),
        toFirestore: (state, _) => state.toJson(),
      );

  FirestoreController({required this.instance, required this.gameState}) {
    // 1) Remoto → Local: escucha cambios de Firestore y actualiza el estado local
    _remoteSub = _ref.snapshots().listen((snap) {
      final remote = snap.data();
      if (remote != null && remote != gameState.estado) {
        gameState.updateFrom(remote);
      }
    });

    // 2) Local → Remoto: sube los cambios del jugador a Firestore
    _localSub = gameState.playerChanges.listen((_) async {
      await _ref.set(gameState.estado);
    });
  }

  void dispose() {
    _remoteSub?.cancel();
    _localSub?.cancel();
  }
}
```

**Dónde vive en nuestra arquitectura:**
- La interfaz va en `game/domain/` (contrato puro).
- La implementación con `FirestoreController` va en `game/data/game_repository.dart`.
- La pantalla de juego (presentation) crea y destruye el controller en `initState/dispose`.

**Notas de implementación:**
- Usar `withConverter<T>` para serialización type-safe (nunca `Map<String,dynamic>` suelto).
- Comparar antes de actualizar (`listEquals`) para evitar loops de sincronización.
- Siempre llamar `dispose()` al salir de la pantalla.
- En macOS: habilitar el [internet entitlement](https://docs.flutter.dev/data-and-backend/networking#macos).

### Estructura recomendada del documento `games/{gameId}`

```
games/{gameId}
├── roomId: string
├── round: int
├── phase: 'betting' | 'playing' | 'dealer' | 'finished'
├── createdAt: timestamp
├── players: { uid: { manos: [...], indiceMano: int, done: bool } }
├── dealerCards: [{ palo, valor }, ...]
├── dealerHidden: bool
└── shoe: [...]   // solo escribible por Cloud Functions
```

---

## 3. Anuncios — Google Mobile Ads SDK

Fuente: https://docs.flutter.dev/resources/ads-overview

**Paquete oficial:** `google_mobile_ads`

### Formatos disponibles

| Formato | Cuándo usar |
|---------|-------------|
| **Rewarded** | ← principal: "ver anuncio → +200 créditos" |
| Rewarded Interstitial | Al terminar partida |
| Interstitial | Entre rondas (con moderación) |
| Banner | Pie de pantalla en lobby |
| App Open | Al reabrir la app |
| Native | Personalizable en UI |

### Flujo Rewarded Ad (ver anuncio → créditos)

```
Cliente Flutter          Cloud Function (rewardAd)
      │                         │
      │─── ver anuncio ────────►│
      │                         │ verificar lastAdReward < 1h
      │◄── reward callback ─────│ balance += 200
      │                         │ guardar lastAdReward = now
      │ UI actualiza saldo       │
```

**Importante:** La validación del reward **nunca** se hace en el cliente.
El callback del SDK llama a la Cloud Function `rewardAd`; ella verifica el límite 1/hora
y actualiza el balance en Firestore. El cliente solo muestra el nuevo saldo.

### Mediación (maximizar ingresos)

Si en el futuro se quiere maximizar eCPM, agregar mediadores:

```yaml
# pubspec.yaml (Fase 7)
gma_mediation_applovin: ...
gma_mediation_meta: ...
gma_mediation_unity: ...
```

### Mejores prácticas

- Cargar el anuncio **antes** de que el usuario lo solicite (preload en el lobby).
- Usar IDs de prueba durante desarrollo para no arriesgar la cuenta AdMob.
- Siempre llamar `dispose()` sobre el objeto `RewardedAd`.

---

## 4. Logros y leaderboards

**Paquete oficial:** `games_services`

Integra con:
- **Android:** Google Play Games Services
- **iOS:** Game Center (GameKit)

```dart
// Desbloquear logro (ej: "Primera partida ganada")
await GamesServices.unlock(
  achievement: Achievement(
    androidID: 'CgkI...',
    iOSID: 'com.robertgon97.blackjack21.achievement.first_win',
  ),
);

// Enviar puntuación al leaderboard
await GamesServices.submitScore(
  score: Score(
    androidLeaderboardID: 'CgkI...',
    iOSLeaderboardID: 'com.robertgon97.blackjack21.leaderboard.balance',
    value: playerBalance,
  ),
);
```

> Para el **leaderboard interno** de la app (pantalla de clasificación con saldo),
> Firestore es más flexible. `games_services` es para la integración con la tienda
> (insignias nativas, notificaciones de Play/Game Center).

---

## 5. Sonidos

**Paquete oficial (toolkit):** `audioplayers`

Alternativa de alta performance: `flutter_soloud` (para web/desktop con latencia baja).

En nuestro proyecto: los sonidos (fichas, cartas, chips) se implementan en la **Fase 7**.
La referencia JS usa Web Audio API; en Flutter usamos `audioplayers`.

---

## 6. Arquitectura — alineación con la oficial

Flutter documenta una arquitectura de 3 capas en https://docs.flutter.dev/app-architecture
que coincide exactamente con la nuestra:

| Capa Flutter | Capa nuestra | Contenido |
|---|---|---|
| Data layer | `feature/data/` | Repositorios, datasources (Firestore) |
| Domain / Business logic | `feature/domain/` | Entidades puras, interfaces, lógica |
| UI layer | `feature/presentation/` | Widgets + Riverpod providers |

**Validación oficial de Riverpod:** está reconocido como opción válida en
https://docs.flutter.dev/data-and-backend/state-mgmt/options.
Para datos de Firestore en tiempo real, el patrón `StreamProvider` es el más idiomático.

---

## 7. URLs de referencia útiles para desarrollo

| Recurso | URL |
|---------|-----|
| Games Toolkit | https://docs.flutter.dev/resources/games-toolkit |
| Cookbook: Multiplayer Firestore | https://docs.flutter.dev/cookbook/games/firestore-multiplayer |
| Cookbook: In-game ads | https://docs.flutter.dev/cookbook/plugins/google-mobile-ads |
| Cookbook: Achievements | https://docs.flutter.dev/cookbook/games/achievements-leaderboard |
| Ads overview | https://docs.flutter.dev/resources/ads-overview |
| App Architecture guide | https://docs.flutter.dev/app-architecture |
| State management options | https://docs.flutter.dev/data-and-backend/state-mgmt/options |
| Card Game Template | https://github.com/flutter/games/tree/main/templates/card |
| I/O FLIP (juego de cartas open source) | https://github.com/google/io-flip |
| I/O Pinball (Flame + Firebase) | https://github.com/flutter/pinball |
| Codelab: AdMob en Flutter | https://codelabs.developers.google.com/codelabs/admob-ads-in-flutter |
| Codelab: Firebase Auth en Flutter | https://firebase.google.com/codelabs/firebase-auth-in-flutter-apps |

---

## 8. Paquetes confirmados por fase

Actualizar `pubspec.yaml` al inicio de cada fase:

```yaml
# Fase 2 — UI
flutter_riverpod: ^2.x
go_router: ^14.x
audioplayers: ^6.x          # sonidos (opcional hasta Fase 7)

# Fase 3 — Firebase
firebase_core: ^3.x
firebase_auth: ^5.x
cloud_firestore: ^5.x
cloud_functions: ^5.x
google_sign_in: ^6.x

# Fase 5 — Multijugador (ya incluido en firebase)
# → usa cloud_firestore con el patrón FirestoreController

# Fase 6 — Comunicación
livekit_client: ^2.x         # voz/cámara
permission_handler: ^11.x    # permisos micro/cámara

# Fase 7 — Monetización
google_mobile_ads: ^5.x
games_services: ^4.x         # logros + leaderboard nativo
in_app_purchase: ^3.x        # compras (opcional)
firebase_messaging: ^15.x    # notificaciones push
```
