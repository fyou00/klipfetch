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
-dontwarn org.apache.commons.**
-dontwarn org.tukaani.xz.**
