# ============================================================
# Reglas R8 / ProGuard — Blackjack 21
#
# Mantenemos la minificación + ofuscación activas (seguridad), pero
# preservamos las clases de Firebase que se cargan por REFLEXIÓN durante
# `Firebase.initializeApp()`. Sin estas reglas, R8 elimina los
# *Registrar (p. ej. CrashlyticsRegistrar) y la inicialización falla con
#   "FirebaseCrashlytics component is not present"
# antes de llegar a runApp() → la app arranca en PANTALLA NEGRA.
# Ver docs/errores-y-correcciones.md.
# ============================================================

# --- Firebase (núcleo + todos los servicios usados) ---
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# --- ComponentRegistrar: se instancian por reflexión con su constructor
#     sin argumentos. R8 borraba ese <init> y rompía el ComponentDiscovery. ---
-keep class * implements com.google.firebase.components.ComponentRegistrar { *; }
-keepnames class com.google.firebase.components.ComponentRegistrar

# --- Atributos necesarios para reflexión, genéricos y anotaciones ---
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# --- Respetar las clases/miembros anotados con @Keep ---
-keep @androidx.annotation.Keep class * { *; }
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}

# --- WorkManager + Room (firebase_messaging y google_mobile_ads lo usan) ---
# WorkDatabase se instancia por reflexión en AppInitializer; sin estas reglas
# R8 lo elimina y lanza StartupException en dispositivos Samsung (y otros).
-keep class androidx.work.** { *; }
-keepnames class androidx.work.** { *; }
-dontwarn androidx.work.**
-keep class * extends androidx.room.RoomDatabase { *; }
-keep @androidx.room.Database class * { *; }
-keepclassmembers @androidx.room.Database class * { *; }
-dontwarn androidx.room.**

# --- androidx.startup (InitializationProvider) ---
-keep class * implements androidx.startup.Initializer { *; }
-keepnames class * implements androidx.startup.Initializer
-dontwarn androidx.startup.**
