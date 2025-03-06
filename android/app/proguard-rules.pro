# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.plugin.editing.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Supabase
-keep class io.supabase.** { *; }
-keep class com.google.gson.** { *; }

# Play Core
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
-keep class androidx.startup.** { *; }

# Play In-App Update
-keep class com.google.android.play.core.appupdate.** { *; }

# MESA 로그 제거
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
    public static *** w(...);
    public static *** e(...);
    public static *** println(...);
    public static *** wtf(...);
}

# MESA 클래스 로그 제거
-assumenosideeffects class * {
    void debug(...);
    void verbose(...);
    void info(...);
    void trace(...);
    void warn(...);
    void error(...);
}

# MESA 특정 클래스 로그 제거
-assumenosideeffects class org.mesa.** {
    *;
}
-assumenosideeffects class com.android.org.mesa.** {
    *;
}

# Keep R8 rules
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception 