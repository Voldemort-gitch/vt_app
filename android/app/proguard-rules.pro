# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Supabase / PostgREST
-keep class com.supabase.** { *; }
-keep class kotlinx.serialization.** { *; }

# Mobile Scanner (QR)
-keep class com.mlkit.** { *; }
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }

# Biometric
-keep class androidx.biometric.** { *; }

# PDF / Printing
-keep class org.apache.** { *; }

# Models for JSON
-keep class com.vtapp.vt_app.** { *; }

# Play Core (deferred components)
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Keep generic signatures for serialization
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
