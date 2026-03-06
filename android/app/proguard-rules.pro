# flutter_local_notifications — R8 strips Gson type params causing
# "Missing type parameter" crash in release builds
-keep class com.dexterous.** { *; }

# Gson (used internally by flutter_local_notifications for serialization)
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn com.google.gson.**

# Keep Flutter's background callback dispatcher
-keep class io.flutter.** { *; }

# Play Core split-install — referenced by Flutter but not used
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
