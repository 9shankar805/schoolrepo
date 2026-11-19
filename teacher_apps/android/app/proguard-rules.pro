# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Plugin specific rules
-keep class com.tundralabs.fluttertts.** { *; }

# Google Play Core (deferred components)
-dontwarn com.google.android.play.core.**

# Retain annotations and signatures for JSON serialization / reflection
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes SourceFile,LineNumberTable
