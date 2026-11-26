# KlipFetch Android R8 / ProGuard rules

# Flutter Engine & Embedding
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# KlipFetch Native Android Components (MethodChannel, Services, WebView, FileProvider)
-keep class io.github.fyou00.klipfetch.** { *; }

# youtubedl-android (libpython / FFmpeg / Aria2c / JNA native bindings)
-keep class com.yausername.** { *; }
-dontwarn com.yausername.**

# JNA & Jackson / Apache Commons transitive libraries used by youtubedl-android
-keep class com.sun.jna.** { *; }
-keep class * implements com.sun.jna.** { *; }
-dontwarn com.sun.jna.**
-dontwarn java.awt.**

-keep class com.fasterxml.jackson.** { *; }
-dontwarn com.fasterxml.jackson.**

# Preserve reflection & JNI metadata under AGP 9 R8 full mode
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
-keepclasseswithmembernames class * {
    native <methods>;
}

# Apache Commons Compress / IO & XZ (used reflectively by youtubedl-android ZipUtils & ExtraFieldUtils)
-keep class org.apache.commons.compress.** { *; }
-keep class org.apache.commons.io.** { *; }
-keep class org.tukaani.xz.** { *; }
-dontwarn org.apache.commons.**
-dontwarn org.tukaani.xz.**

# Dart JNI / path_provider_android 2.3+ bridge classes
-keep class com.github.dart_lang.jni.** { *; }
-keep class com.github.dart_lang.jni_flutter.** { *; }

# AndroidX Startup initializers
-keep class * extends androidx.startup.Initializer {
    public <init>();
}
