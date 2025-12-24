# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Generative AI
-keep class com.google.ai.** { *; }

# Audioplayers
-keep class xyz.luan.audioplayers.** { *; }

# Flutter Local Notifications
-keep class com.dexterous.** { *; }

# Keep annotations
-keepattributes *Annotation*

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Play Core Library - missing classes fix
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Flutter deferred components
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
