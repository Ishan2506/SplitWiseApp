# --- Google ML Kit text recognition ---
# The Flutter plugin references the optional script-specific recognizers
# (Chinese, Devanagari, Japanese, Korean). We only bundle the Latin model,
# so tell R8 to ignore the dangling references instead of failing the build.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Keep the ML Kit entry points that are resolved reflectively.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }

# --- Flutter ---
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# --- Play Core / deferred components ---
# Flutter's embedding references Play Core for deferred component (dynamic
# feature) loading. This app does not use deferred components and does not
# ship the Play Core library, so ignore the unresolved references.
-dontwarn com.google.android.play.core.**
