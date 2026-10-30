# FinPay release rules. Dart code is obfuscated by the Flutter tool
# (`flutter build apk --release --obfuscate --split-debug-info=build/symbols`);
# R8 handles the Android side (minify + shrink are on in build.gradle.kts).

# Flutter embedding and plugin registrant.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Our activity hosts the screen-protector method channel.
-keep class com.finpay.app.MainActivity { *; }

# local_auth uses androidx.biometric reflection-free, but keep the
# fragment activity surface R8 might otherwise strip.
-keep class androidx.biometric.** { *; }
-keep class androidx.fragment.app.FragmentActivity { *; }

# flutter_secure_storage (Tink / Keystore wrappers).
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.errorprone.annotations.**

# Native methods and Parcelables.
-keepclasseswithmembernames class * {
    native <methods>;
}
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Strip Android logging in release.
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}
