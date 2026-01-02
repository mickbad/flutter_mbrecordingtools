# Règles ProGuard simplifiées pour éviter les erreurs R8
# et garantir que l'application fonctionne correctement

# Garder les classes Flutter essentielles
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }

# Garder les classes des plugins utilisés
-keep class com.llfbandit.record.** { *; }
-keep class id.flutter.flutter_background_service.** { *; }
-keep class com.dexterous.** { *; }
-keep class com.baseflow.permissionhandler.** { *; }
-keep class dev.fluttercommunity.plus.device_info.** { *; }
-keep class io.flutter.plugins.pathprovider.** { *; }
-keep class com.github.uuid.** { *; }
-keep class xyz.luan.audioplayers.** { *; }

# Garder les classes natives et reflexión
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes Signature
-keepattributes EnclosingMethod
-keep class * extends java.lang.annotation.Annotation { *; }

# Garder les classes Parcelable
-keepclassmembers class * implements android.os.Parcelable {
  public static final android.os.Parcelable$Creator CREATOR;
}

# Garder les classes natives
-keepclasseswithmembernames class * {
    native <methods>;
}

# Éviter les warnings
-dontwarn org.bouncycastle.**
-dontwarn javax.annotation.**
-dontwarn javax.inject.**
-dontwarn com.google.errorprone.annotations.**

# Garder les classes main
-keep class com.example.mbrecordingtools_sample.MainActivity { *; }