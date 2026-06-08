# CI/CD, firmas y releases

> Basado en: https://docs.flutter.dev/deployment/cd · /android · /ios · /web
>
> **Regla:** el código sin firmar no llega a producción. Esta guía cubre todo lo necesario
> para que los workflows de GitHub Actions generen binarios listos para distribuir.

---

## 1. Android — crear el keystore (acción manual, una sola vez)

El keystore es el certificado que firma la app. **Nunca se sube al repo.**

```powershell
# Windows (PowerShell) — ejecutar en tu máquina local
keytool -genkey -v `
  -keystore $env:USERPROFILE\upload-keystore.jks `
  -storetype JKS `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -alias upload
```

Responde a las preguntas interactivas (nombre, organización, ciudad, país).
Guarda bien la contraseña: la necesitarás en el siguiente paso y si la pierdes
**no puedes recuperar el keystore**.

> **⚠️ Importante:** `upload-keystore.jks` nunca debe entrar al repositorio.
> `android/key.properties` tampoco — ya están en `.gitignore`.

---

## 2. Android — configurar `key.properties`

Crea el archivo `android/key.properties` en tu máquina local (no lo commitees):

```properties
storePassword=<contraseña del keystore>
keyPassword=<contraseña del keystore>
keyAlias=upload
storeFile=C:\\Users\\rober\\upload-keystore.jks
```

> En Windows usa `\\` como separador de rutas.

---

## 3. Android — actualizar `build.gradle.kts`

Edita `android/app/build.gradle.kts` para leer `key.properties` y firmar el build de release:

```kotlin
import java.util.Properties
import java.io.FileInputStream

// Cargar key.properties si existe (CI lo recrea desde secretos; local lo tiene el dev)
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // ... configuración existente ...

    signingConfigs {
        create("release") {
            keyAlias     = keystoreProperties["keyAlias"]     as String
            keyPassword  = keystoreProperties["keyPassword"]  as String
            storeFile    = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

Después de cambiar el signing, ejecuta `flutter clean` antes del siguiente build.

---

## 4. Android — GitHub Secrets

En **Settings → Secrets and variables → Actions → New repository secret**, crea:

| Secret | Valor |
|--------|-------|
| `ANDROID_KEYSTORE_BASE64` | `base64 -i ~/upload-keystore.jks \| pbcopy` (mac) o codifica con PowerShell |
| `ANDROID_KEYSTORE_PASSWORD` | contraseña del keystore |
| `ANDROID_KEYSTORE_KEY_ALIAS` | `upload` |
| `ANDROID_KEYSTORE_KEY_PASSWORD` | contraseña de la clave (normalmente igual a la del store) |

**Codificar el keystore en base64 (PowerShell):**
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$env:USERPROFILE\upload-keystore.jks")) | clip
# Pega el resultado en el secret ANDROID_KEYSTORE_BASE64
```

---

## 5. Android — APK vs App Bundle

| Formato | Cuándo usar |
|---------|-------------|
| **`.aab` (App Bundle)** | Play Store — **recomendado**; Google genera APKs optimizadas por dispositivo |
| **`.apk` (fat)** | Distribución directa fuera de Play Store, sideloading |
| **`.apk --split-per-abi`** | Si distribuyes APKs directamente, separa por arquitectura para reducir tamaño |

```bash
# Para Play Store (preferido)
flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab

# Para distribución directa / GitHub Release
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk

# APK separadas por arquitectura (más pequeñas)
flutter build apk --split-per-abi --release
# → app-armeabi-v7a-release.apk · app-arm64-v8a-release.apk · app-x86_64-release.apk
```

---

## 6. iOS — requisitos (cuenta Apple Developer US$99/año)

La firma de iOS requiere una cuenta en https://developer.apple.com.

**Pasos iniciales (una sola vez):**
1. Registrar Bundle ID: `com.robertgon97.blackjack21` en https://developer.apple.com/account/ios/identifier/bundle
2. Crear certificado **iOS App Store Distribution** (no Development)
3. Exportar como `.p12` + contraseña
4. Crear Provisioning Profile **App Store**
5. Crear API Key en https://appstoreconnect.apple.com/access/api (role: App Manager)
   - Descarga `AuthKey_XXXXXXX.p8`
   - Anota: Issuer ID y Key ID

**GitHub Secrets adicionales para iOS:**

| Secret | Valor |
|--------|-------|
| `APP_STORE_CONNECT_ISSUER_ID` | UUID del issuer |
| `APP_STORE_CONNECT_KEY_IDENTIFIER` | ID de la API Key |
| `APP_STORE_CONNECT_PRIVATE_KEY` | Contenido del `.p8` |
| `IOS_CERT_P12_BASE64` | Certificado `.p12` en base64 |
| `IOS_CERT_PASSWORD` | Contraseña del `.p12` |

**Comandos de build iOS:**
```bash
flutter build ipa --release
# → build/ios/ipa/*.ipa

# Con obfuscación (recomendado para producción)
flutter build ipa --release --obfuscate --split-debug-info=build/app/outputs/symbols
```

**Upload a App Store Connect:**
```bash
# Vía xcrun (en macOS runner del CI)
xcrun altool --upload-app \
    --type ios \
    -f build/ios/ipa/*.ipa \
    --apiKey $APP_STORE_CONNECT_KEY_IDENTIFIER \
    --apiIssuer $APP_STORE_CONNECT_ISSUER_ID
```

---

## 7. Web — renderer y build de producción

Para Blackjack web la elección correcta es **CanvasKit** (default desde Flutter 3.x):

| Renderer | Compatibilidad | Rendimiento | Cuándo usar |
|----------|----------------|-------------|-------------|
| **CanvasKit** | ✅ Todos los navegadores | Bueno | **Ahora** (MVP) |
| Skwasm (WASM) | ❌ Solo Chrome 119+ | Mejor | Futuro, cuando Firefox/Safari soporten WasmGC |

```bash
# Build de producción (CanvasKit, es el default)
flutter build web --release --base-href /blackjack-21/

# Build con WASM (futuro — requiere Chrome 119+)
flutter build web --wasm --release
```

Para detectar en código si corre con WASM:
```dart
const isWasm = bool.fromEnvironment('dart.tool.dart2wasm');
```

Si en el futuro habilitas WASM en producción, el servidor debe enviar estos headers:
```
Cross-Origin-Embedder-Policy: credentialless
Cross-Origin-Opener-Policy: same-origin
```

---

## 8. Flavors — separar dev de prod

Para separar la app de desarrollo (con emuladores Firebase) de la de producción.

**`android/app/build.gradle.kts`** — agregar tras `defaultConfig`:
```kotlin
flavorDimensions += "default"
productFlavors {
    create("dev") {
        dimension = "default"
        applicationIdSuffix = ".dev"
        resValue("string", "app_name", "Blackjack Dev")
    }
    create("prod") {
        dimension = "default"
        applicationIdSuffix = ""
        resValue("string", "app_name", "Blackjack 21")
    }
}
```

**Comandos con flavor:**
```bash
flutter run --flavor dev -d chrome         # desarrollo
flutter build apk --flavor prod --release  # producción
flutter build web --flavor prod --release  # web producción
```

> **Pendiente Fase 3:** cuando se configure `flutterfire configure`, generar
> `google-services.json` y `GoogleService-Info.plist` por separado para dev y prod,
> y colocarlos en `android/app/src/dev/` y `android/app/src/prod/`.

---

## 9. Deep links `/join/CODIGO`

Los deep links son la forma en que un usuario en el chat o WhatsApp abre directamente la sala.

**`android/app/src/main/AndroidManifest.xml`** — agregar intent filter:
```xml
<activity android:name=".MainActivity" android:launchMode="singleTop">
    <!-- ... -->
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data
            android:scheme="https"
            android:host="robertgon97.github.io"
            android:pathPrefix="/blackjack-21/join" />
    </intent-filter>
</activity>
```

**Web:** Flutter maneja automáticamente los paths. Con `PathUrlStrategy` (configurada en `main.dart`):
```
https://robertgon97.github.io/blackjack-21/join/ABC123
```
Sin `PathUrlStrategy` (hash mode, default):
```
https://robertgon97.github.io/blackjack-21/#/join/ABC123
```

El hash mode funciona en GitHub Pages sin configuración adicional; el path mode
requiere que el servidor sirva `index.html` para cualquier ruta (puede necesitar
`404.html` workaround en GitHub Pages).

**iOS** (`ios/Runner/Info.plist`) — agregar:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>blackjack21</string>
        </array>
    </dict>
</array>
```

---

## 10. Workflow `release.yml` actualizado (con firma real)

Ver el archivo `.github/workflows/release.yml` en el repo. El workflow actualizado:
1. Decodifica el keystore desde el secret Base64
2. Recrea `key.properties` con los valores de los secrets
3. Genera APK firmada + AAB firmado
4. Sube ambos a la GitHub Release

**Pendiente antes de usar en producción:**
- [ ] Crear keystore local (`keytool` — Paso 1 de este doc)
- [ ] Agregar los 4 secrets de Android a GitHub
- [ ] Actualizar `android/app/build.gradle.kts` con el bloque de `signingConfigs`
- [ ] Para iOS: cuenta Apple Developer + secrets adicionales

---

## 11. Testing del pipeline localmente

```bash
# Simular build de release (sin firma real, para verificar que compila)
flutter build apk --release

# Verificar que la firma está configurada
flutter build appbundle --release

# Instalar APK en dispositivo conectado para smoke test
flutter install
```
