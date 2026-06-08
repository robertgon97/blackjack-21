# Estrategia de testing

> Basado en: https://docs.flutter.dev/testing/overview · /integration-tests · /code-coverage

---

## Pirámide de tests

```
        ▲  Integration tests
       ▲▲▲  (flujos completos, Fase 5+)
      ▲▲▲▲▲  Widget tests
     ▲▲▲▲▲▲▲  (pantallas y componentes, Fase 2+)
    ▲▲▲▲▲▲▲▲▲  Unit tests — domain layer
   ▲▲▲▲▲▲▲▲▲▲▲  (32 tests ya verdes ✅)
```

La base (unit tests del domain) ya existe. Los niveles superiores se agregan por fase.

---

## Nivel 1 — Unit tests (ya completos)

Cubren la capa `domain`: cálculos de puntos, estrategia básica, resolución de manos.

```bash
flutter test              # 32 tests
flutter test --coverage   # genera coverage/lcov.info
```

**Paquetes:**
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.0   # Mocking moderno (preferido sobre mockito para Dart 3)
```

**Patrón AAA para tests nuevos:**
```dart
test('descripción del comportamiento esperado', () {
  // Arrange
  final config = const ConfigJuego(empujeEn22: true);

  // Act
  final resultado = resolverMano(mano: mano, manoCrupier: crupier22, config: config, esUnicaMano: true);

  // Assert
  expect(resultado.estado, EstadoMano.empate);
});
```

---

## Nivel 2 — Widget tests (Fase 2)

Verifican que la UI se renderiza correctamente y responde a interacciones.

**Qué cubrir:**
- Cada pantalla se renderiza sin errores
- Los botones (Pedir, Plantarse, Doblar) ejecutan la acción correcta
- Los estados visuales (cargando, error, éxito) se muestran bien
- La UI es usable con escala de texto al 200% (`textScaleFactor`)

**Estructura:**
```
test/
  domain/          ← tests actuales
  presentation/    ← widget tests (agregar en Fase 2)
    game_screen_test.dart
    lobby_screen_test.dart
    auth_screen_test.dart
  fixtures/        ← datos falsos reutilizables
    fake_game_state.dart
    fake_user.dart
```

**Ejemplo:**
```dart
testWidgets('botón Pedir está deshabilitado cuando la mano está terminada', (tester) async {
  await tester.pumpWidget(
    const ProviderScope(
      overrides: [
        // Inyectar estado falso para el test
        estadoPartidaProvider.overrideWithValue(AsyncData(estadoFinalizado)),
      ],
      child: MaterialApp(home: BotonesAccion()),
    ),
  );

  final boton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Pedir'));
  expect(boton.onPressed, isNull); // Deshabilitado
});
```

**Regla:** siempre usa `Keys` en widgets importantes para localizarlos en tests:
```dart
ElevatedButton(
  key: const ValueKey('btn_pedir'),
  onPressed: onPedir,
  child: const Text('Pedir'),
)

// En el test:
await tester.tap(find.byKey(const ValueKey('btn_pedir')));
```

---

## Nivel 3 — Integration tests (Fase 5+)

Verifican flujos completos end-to-end sobre la app real (no mocks).

**Directorio:**
```
integration_test/
  app_test.dart              ← smoke test básico
  game_flow_test.dart        ← deal → hit → stand → resultado
  auth_flow_test.dart        ← registro → login → perfil
  multiplayer_flow_test.dart ← crear sala → invitar → jugar
```

**Estructura mínima:**
```dart
// integration_test/game_flow_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('flujo completo de una mano', (tester) async {
    await tester.pumpWidget(const BlackjackApp());
    await tester.pumpAndSettle();

    // Login anónimo
    await tester.tap(find.byKey(const ValueKey('btn_jugar_sin_cuenta')));
    await tester.pumpAndSettle();

    // Apostar y repartir
    await tester.tap(find.byKey(const ValueKey('btn_apostar_10')));
    await tester.tap(find.byKey(const ValueKey('btn_deal')));
    await tester.pumpAndSettle();

    // Pantalla de juego visible
    expect(find.byType(TapeteWidget), findsOneWidget);
  });
}
```

**Correr integration tests:**
```bash
flutter test integration_test/ -d chrome    # web
flutter test integration_test/ -d emulator  # Android
```

---

## Code coverage en CI

Agrega al `ci.yml` después del paso de tests:

```yaml
- name: Tests con coverage
  run: flutter test --coverage

- name: Subir coverage a Codecov
  uses: codecov/codecov-action@v4
  with:
    files: ./coverage/lcov.info
    fail_ci_if_error: false  # No bloquear CI si falla el upload
```

**Ver coverage localmente (HTML):**
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
# Abrir coverage/html/index.html en el navegador
```

**Agregar `genhtml` al CI (Ubuntu):**
```yaml
- name: Instalar lcov
  run: sudo apt-get install -y lcov

- name: Generar reporte HTML
  run: genhtml coverage/lcov.info -o coverage/html

- name: Subir reporte como artefacto
  uses: actions/upload-artifact@v4
  with:
    name: coverage-report
    path: coverage/html
```

**Target de coverage por capa:**

| Capa | Target |
|------|--------|
| `domain/` | **100%** — lógica pura, sin excusas |
| `data/` | 70%+ — repositorios con mocks de Firestore |
| `presentation/` | 50%+ — widget tests de pantallas principales |

---

## Performance — 60 FPS en el tapete

Flutter apunta a 16ms por frame (60fps). Para Blackjack:

**Reglas de oro:**

```dart
// 1. const en todos los widgets que no cambian
const CartaWidget(palo: '♠', valor: 'A')

// 2. NO setState() en la raíz — usar providers locales
// ❌ Mal: reconstruye TODO el tapete
setState(() { _mano = nuevaMano; });

// ✅ Bien: solo reconstruye el widget de la mano
ref.read(manoProvider.notifier).actualizar(nuevaMano);

// 3. Animaciones con AnimatedWidget, NO Opacity en animaciones
// ❌ Opacidad en animación = capa offscreen cada frame
AnimatedOpacity(opacity: valor, duration: duration, child: carta)

// 4. Listas largas (historial de movimientos) con ListView.builder
ListView.builder(
  itemCount: historial.length,
  itemBuilder: (_, i) => EntradaHistorial(historial[i]),
)
```

**Profiling:**
```bash
flutter run --profile  # nunca en debug para medir performance
# Abre DevTools → Performance tab → graba unos segundos de juego
```

---

## Accesibilidad — checklist pre-lanzamiento

| Check | Cómo |
|-------|------|
| Botones ≥ 48×48 px | `ElevatedButton` lo cumple automáticamente |
| Contraste texto ≥ 4.5:1 | Verificar con DevTools Accessibility Audit |
| Screen readers | Probar con TalkBack (Android) / VoiceOver (iOS) |
| No solo color para indicar estado | Icono + color + texto |
| `Semantics` en widgets custom | `Semantics(label: 'Carta: As de picas', child: ...)` |
| Text scale 200% | `tester.binding.window.textScaleFactorTestValue = 2.0` |

**Ejemplo de widget accesible:**
```dart
Semantics(
  label: 'Carta: ${carta.valor} de ${carta.palo.name}',
  hint: 'Doble toque para voltear',
  button: false,
  child: CartaWidget(carta: carta),
)
```
