# ProGuard rules for A-Network app
# Prevent obfuscation of critical classes

# Keep all custom classes
-keep class com.anetwork.** { *; }

# Keep Flutter classes
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }

# Google Mobile Ads SDK removed (AdSense/AdMob banned). Axon ads TBD.

# Keep Google Play Core libraries (InApp Updates, Split Install, etc.)
-keep class com.google.android.play.core.** { *; }
-keep interface com.google.android.play.core.** { *; }
-keepattributes Signature

# Ignore missing Google Play Core classes warnings (optional library)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Keep API service classes
-keep class * { public <init>(); }

# Keep all public methods
-keepclassmembers class * {
    public *;
}

# Remove logging
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

# Minimize log spam
-dontwarn com.google.android.gms.**
-dontwarn java.lang.invoke.**
