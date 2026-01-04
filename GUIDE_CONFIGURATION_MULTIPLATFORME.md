# Guide de Configuration Multiplateforme - MBRecordingTools

Ce guide résume toutes les actions nécessaires pour configurer et utiliser le plugin `flutter_mbrecordingtools` sur Android, iOS, macOS et Windows.

## Table des Matières

1. [Prérequis Généraux](#prérequis-généraux)
2. [Configuration Android](#configuration-android)
3. [Configuration iOS](#configuration-ios)
4. [Configuration macOS](#configuration-macos)
5. [Configuration Windows](#configuration-windows)
6. [Initialisation du Plugin](#initialisation-du-plugin)
7. [Dépannage Commun](#dépannage-commun)

---

## Prérequis Généraux

### Dépendances requises dans `pubspec.yaml`

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Plugin principal
  mbrecordingtools:
    git: 
        url: https://github.com/mickbad/flutter_mbrecordingtools.git
        ref: [version]

  # Dépendances nécessaires
  permission_handler: ^11.3.1  
  path_provider: ^2.1.3
```

### Versions minimales requises

- **Flutter**: 3.10.0+
- **Dart**: 3.0.0+
- **Android**: API 23+ (Android 6.0)
- **iOS**: 12.0+
- **macOS**: 10.14+
- **Windows**: Windows 10+

---

## Configuration Android

### 1. Permissions dans `android/app/src/main/AndroidManifest.xml`

```xml
<manifest
    xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">

    <!-- Permissions essentielles -->
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />

    <!-- Feature pour le microphone -->
    <uses-feature
        android:name="android.hardware.microphone"
        android:required="false" />
```

### 2. Configuration du Service d'Arrière-Plan

Dans `android/app/src/main/AndroidManifest.xml`, à l'intérieur de `<application>` :

```xml
<application
    android:label="mbrecordingtools_sample"
    android:name="${applicationName}"
    android:icon="@mipmap/ic_launcher"
    android:allowBackup="true"
    android:requestLegacyExternalStorage="true"
    android:preserveLegacyExternalStorage="true">

    <!-- Service d'enregistrement en arrière-plan -->
    <service
        android:name="id.flutter.flutter_background_service.BackgroundService"
        android:foregroundServiceType="microphone"
        tools:replace="android:exported"
        android:exported="false" />
</application>
```

### 3. Configuration Gradle dans `android/app/build.gradle.kts`

```kotlin
android {
    compileSdk = 36
    ndkVersion = "29.0.13113456"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
  
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // Désactiver la minification pour éviter les erreurs R8
            isMinifyEnabled = false
            isShrinkResources = false

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.window:window:1.0.0")
    implementation("androidx.window:window-java:1.0.0")
}
```

### 4. Règles ProGuard dans `android/app/proguard-rules.pro`

```proguard
# Règles simplifiées pour éviter les erreurs R8
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
```

### 5. Demande de Permissions Runtime

```dart
import 'package:permission_handler/permission_handler.dart';

Future<void> requestAndroidPermissions() async {
  // Permissions de base
  await [
    Permission.microphone,
    Permission.storage,
  ].request();

  // Permission pour Android 13+
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
}
```

---

## Configuration iOS

### 1. Configuration Info.plist dans `ios/Runner/Info.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Permissions essentielles -->
    <key>NSMicrophoneUsageDescription</key>
    <string>Cette application a besoin d'accéder au microphone pour enregistrer de l'audio.</string>
    
    <!-- Modes d'arrière-plan -->
    <key>UIBackgroundModes</key>
    <array>
        <string>audio</string>
        <string>processing</string>
    </array>

    <!-- Configuration pour les notifications -->
    <key>NSUserNotificationsUsageDescription</key>
    <string>Cette application envoie des notifications pour les enregistrements en arrière-plan.</string>
</dict>
</plist>
```

### 2. Configuration des Capacités dans Xcode

1. Ouvrez `ios/Runner.xcworkspace` dans Xcode
2. Sélectionnez votre target Runner
3. Dans l'onglet "Signing & Capabilities", ajoutez :
   - **Background Modes** (Audio, AirPlay, and Picture-in-Picture)
   - **Microphone Usage Description**

### 3. Configuration du Podfile

Assurez-vous que `ios/Podfile` contient :

```ruby
# Pour l'enregistrement en arrière-plan
config.build_settings['ENABLE_APP_CONTINUOUS_INTEGRATION'] = 'YES'
config.build_settings['ENABLE_BITCODE'] = 'NO'

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['ENABLE_BITCODE'] = 'NO'
    end
  end
end
```

### 4. Installation des Dépendances iOS

```bash
cd ios
pod install --repo-update
```

### 5. Demande de Permissions iOS

```dart
import 'package:permission_handler/permission_handler.dart';

Future<void> requestIOSPermissions() async {
  await Permission.microphone.request();
  await Permission.notification.request();
}
```

---

## Configuration macOS

### 1. Configuration Info.plist dans `macos/Runner/Info.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSMicrophoneUsageDescription</key>
    <string>Cette application a besoin d'accéder au microphone pour enregistrer de l'audio.</string>
    
    <key>NSUserNotificationsUsageDescription</key>
    <string>Cette application envoie des notifications pour les enregistrements en arrière-plan.</string>
</dict>
</plist>
```

### 2. Configuration des Entitlements dans `macos/Runner/DebugProfile.entitlements`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.device.microphone</key>
    <true/>
    <key>com.apple.security.device.audio-input</key>
    <true/>
</dict>
</plist>
```

### 3. Installation des Dépendances macOS

```bash
cd macos
pod install
```

### 4. Demande de Permissions macOS

```dart
import 'package:permission_handler/permission_handler.dart';

Future<void> requestMacOSPermissions() async {
  await Permission.microphone.request();
  await Permission.notification.request();
}
```

---

## Configuration Windows

### 1. Permissions dans `windows/runner/main.cpp`

Ajoutez les headers nécessaires :

```cpp
#include <windows.h>
#include <mmdeviceapi.h>
#include <endpointvolume.h>
```

### 2. Configuration des Capacités dans `windows/runner/CMakeLists.txt`

```cmake
# Configuration des permissions Windows
set(WINRT_ENABLE_MICROPHONE ON)
set(WINRT_ENABLE_AUDIO ON)
```

### 3. Configuration des Dépendances dans `windows/runner/main.cpp`

```cpp
// Initialisation COM pour l'accès au microphone
CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
```

### 4. Demande de Permissions Windows

```dart
import 'package:permission_handler/permission_handler.dart';

Future<void> requestWindowsPermissions() async {
  await Permission.microphone.request();
  await Permission.notification.request();
}
```

### 5. Configuration du Store Package dans `windows/runner/main.cpp`

```cpp
// Configuration pour les capacités microphone
AddCapability(L"microphone");
```

---

## Initialisation du Plugin

### 1. Configuration Initiale dans `main.dart`

```dart
import 'package:mbrecordingtools/mbrecordingtools.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialisation des services
  await BackgroundAudioService.init();
  await BackgroundSTTService.init();
  
  // Demande des permissions selon la plateforme
  await requestPlatformPermissions();
  
  runApp(const MyApp());
}

Future<void> requestPlatformPermissions() async {
  if (Platform.isAndroid) {
    await requestAndroidPermissions();
  } else if (Platform.isIOS) {
    await requestIOSPermissions();
  } else if (Platform.isMacOS) {
    await requestMacOSPermissions();
  } else if (Platform.isWindows) {
    await requestWindowsPermissions();
  }
}
```

### 2. Vérification des Modèles Disponibles

```dart
// Vérifier les modèles compatibles avec l'appareil
final models = await BackgroundSTTService.getAvailableModels();
final canLoadModel = !await BackgroundSTTService.isRamInsufficient();

// Charger un modèle approprié
await BackgroundSTTService.loadModel(models.first);
```

---

## Dépannage Commun

### Problèmes Android

#### Erreur "MissingPluginException"
```bash
flutter clean
flutter pub get
flutter run
```

#### Erreur "Permission Denied"
- Vérifiez les permissions dans `AndroidManifest.xml`
- Demandez les permissions au runtime
- Redémarrez l'appareil

#### Erreur "R8 Compilation"
```kotlin
// Dans build.gradle.kts
buildTypes {
    release {
        isMinifyEnabled = false
    }
}
```

#### Problème "Insufficient RAM"
- Utilisez un modèle plus petit (`tiny` ou `base`)
- Fermez les autres applications
- Redémarrez l'appareil

### Problèmes iOS

#### Erreur "Microphone Access Denied"
1. Vérifiez `NSMicrophoneUsageDescription` dans `Info.plist`
2. Allez dans Paramètres iOS > Confidentialité > Microphone
3. Activez l'autorisation pour votre app

#### Erreur "Background Audio"
1. Vérifiez que `UIBackgroundModes` contient `audio`
2. Activez les Background Modes dans Xcode
3. Testez avec `pod install --repo-update`

### Problèmes macOS

#### Erreur "Microphone Access Denied"
1. Vérifiez `NSMicrophoneUsageDescription` dans `Info.plist`
2. Allez dans Préférences Système > Sécurité & Confidentialité > Microphone
3. Activez l'autorisation pour votre app

#### Erreur "Entitlements"
- Vérifiez que les entitlements contiennent `com.apple.security.device.microphone`

### Problèmes Windows

#### Erreur "Microphone Access"
1. Vérifiez les paramètres Windows > Confidentialité > Microphone
2. Activez l'accès au microphone
3. Activez les applications de bureau

### Tests de Fonctionnement

#### Test de Base
```dart
// Test de l'enregistrement
final isRecording = await BackgroundAudioService.isRecording();
if (!isRecording) {
  await BackgroundAudioService.start();
  await Future.delayed(Duration(seconds: 5));
  final path = await BackgroundAudioService.stop();
  print('Enregistrement terminé: $path');
}
```

#### Test de Transcription
```dart
// Test de transcription
if (await BackgroundSTTService.isModelLoaded()) {
  final result = await BackgroundSTTService.transcribe(
    audioPath: audioPath,
    lang: 'auto',
  );
  print('Transcription: ${result.text}');
}
```

---

## Commandes de Build Recommandées

### Android
```bash
# Build de release
./build_android.sh release

# Ou manuellement
flutter clean
flutter pub get
flutter build apk --release
```

### iOS
```bash
cd ios
pod install --repo-update
cd ..
flutter clean
flutter pub get
flutter build ios --release
```

### macOS
```bash
cd macos
pod install
cd ..
flutter clean
flutter pub get
flutter build macos --release
```

### Windows
```bash
flutter clean
flutter pub get
flutter build windows --release
```

---

## Vérifications Finales

Avant de déployer, vérifiez :

- [ ] Permissions correctement configurées sur toutes les plateformes
- [ ] Services d'arrière-plan configurés (Android)
- [ ] Modes d'arrière-plan activés (iOS/macOS)
- [ ] Dépendances installées (`pod install`, `flutter pub get`)
- [ ] Tests fonctionnels réalisés sur chaque plateforme
- [ ] Gestion des erreurs implémentée
- [ ] Interface utilisateur adaptée aux permissions

---

## Support

Pour toute question supplémentaire :
1. Consultez la documentation des packages utilisés
2. Vérifiez les logs avec `flutter logs`
3. Testez d'abord en mode debug
4. Utilisez les outils de débogage de chaque plateforme
