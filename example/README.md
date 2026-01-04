MB Recording Tools - Plugin Flutter
=====================================

Ce plugin Flutter permet l'enregistrement audio en arrière-plan avec transcription Whisper GGML et analyse waveform en temps réel.

CONFIGURATION GÉNÉRALE
----------------------

Ajoutez le plugin à votre pubspec.yaml :

```yaml
  # librairie ricochets.dev
  mbrecordingtools:
    git:
      url: https://github.com/mickbad/flutter_mbrecordingtools.git
      ref: [VERSION]
```

Puis importez-le dans votre code :

```dart
import 'package:mbrecordingtools/mbrecordingtools.dart';
```

INITIALISATION
--------------

Dans votre main.dart, initialisez les services :

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BackgroundAudioService.init();
  await BackgroundSTTService.init();
  runApp(const MyApp());
}
```

CONFIGURATION ANDROID
---------------------

1. PERMISSIONS REQUISES

Ajoutez ces permissions dans android/app/src/main/AndroidManifest.xml :

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

2. CONFIGURATION DU SERVICE D'ARRIÈRE-PLAN

Ajoutez cette configuration dans android/app/src/main/AndroidManifest.xml à l'intérieur de <application> :

```xml
<manifest
    xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">

<!-- ... autres permissions ... -->

<activity
    ...
    tools:replace="android:exported"
    android:exported="true" /> <!-- <- mettre cette ligne --> 

<service
    android:name="id.flutter.flutter_background_service.BackgroundService"
    android:foregroundServiceType="microphone"
    tools:replace="android:exported"
    android:exported="false" />
```

3. CONFIGURATION DESUGARING GROOVY

IMPORTANT : Ce plugin utilise flutter_local_notifications qui nécessite le desugaring pour Android.

Dans android/app/build.gradle, ajoutez :

```groovy
android {
    compileSdkVersion 34
    
    compileOptions {
        coreLibraryDesugaringEnabled true
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = '1.8'
    }
}

dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'
    
    implementation 'androidx.work:work-runtime:2.9.0'
}
```

Pour fixer le bug de desugaring Android 12L, ajoutez dans android/app/build.gradle.kts :

```groovy
dependencies {
    implementation 'androidx.window:window:1.0.0'
    implementation 'androidx.window:window-java:1.0.0'
    ...
}
```

4. CONFIGURATION KOTLIN

Si votre projet utilise Kotlin, assurez-vous que android/app/build.gradle contient :

```groovy
android {
    kotlinOptions {
        jvmTarget = '1.8'
    }
}
```

5. CONFIGURATION DESUGARING KOTLIN

Si vous utilisez Kotlin, dans android/app/build.gradle.kts, ajoutez :

```
android {
    defaultConfig {
        multiDexEnabled = true
    }

    compileOptions {
        // Flag to enable support for the new language APIs
        isCoreLibraryDesugaringEnabled = true
        // Sets Java compatibility to Java 
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
  
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

Puis dans settings.gradle.kts, ajoutez :

```
plugins {
    ...
    id("com.android.application") version "8.11.1" apply false
    ...
}
```

Pour fixer le bug de desugaring Android 12L, ajoutez dans android/app/build.gradle.kts :

```
dependencies {
    implementation("androidx.window:window:1.0.0")
    implementation("androidx.window:window-java:1.0.0")
    ...
}
```

Ajouter dans le fichier android/app/build.gradle.kts

```
android {
    compileSdk = 36
    ndkVersion = "29.0.13113456"
    ...
}
```

6. DEMANDE DE PERMISSIONS RUNTIME

Pour Android 6.0+ (API 23+), demandez les permissions au runtime :

```dart
import 'package:permission_handler/permission_handler.dart';

Future<void> _requestPermissions() async {
  await Permission.microphone.request();
  await Permission.storage.request();
}
```

Pour les notifications (Android 13+), ajoutez cette permission dans AndroidManifest.xml :

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

Et demandez-la au runtime :

```dart
await Permission.notification.request();
```

CONFIGURATION IOS
-----------------

1. DESCRIPTION D'UTILISATION DU MICROPHONE

Dans ios/Runner/Info.plist, ajoutez :

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Cette application a besoin d'accéder au microphone pour enregistrer de l'audio.</string>
```

2. MODES D'ARRIÈRE-PLAN

Dans ios/Runner/Info.plist, activez le mode audio en arrière-plan :

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

3. CONFIGURATION POD

Si vous rencontrez des problèmes de linkage, exécutez dans le dossier ios/ :

```bash
pod install --repo-update
```

CONFIGURATION MACOS
-------------------

1. DESCRIPTION D'UTILISATION DU MICROPHONE

Dans macos/Runner/Info.plist, ajoutez :

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Cette application a besoin d'accéder au microphone pour enregistrer de l'audio.</string>
```

2. CONFIGURATION DES PERMISSIONS

macOS nécessite une autorisation explicite pour l'accès au microphone. Les utilisateurs seront invités à l'autoriser lors de la première utilisation.

USAGE DU PLUGIN
---------------

1. ENREGISTREMENT AUDIO

```dart
// Démarrer l'enregistrement
await BackgroundAudioService.start();

// Arrêter l'enregistrement
final audioPath = await BackgroundAudioService.stop();
```

2. TRANSCRIPTION

```dart
// Charger un modèle Whisper
await BackgroundSTTService.loadModel(WhisperModel.base);

// Transcrire un fichier audio
final result = await BackgroundSTTService.transcribe(
  audioPath: audioPath,
  lang: 'auto',
);
```

3. ANALYSE WAVEFORM

```dart
// Utiliser le widget de visualisation
BackgroundAudioLiveWaveform(
  color: Colors.blueAccent,
  countBar: 30,
)
```

DÉPANNAGE
---------

1. ERREUR "PERMISSION_DENIED"

- Vérifiez que les permissions sont correctement déclarées dans les manifestes
- Demandez les permissions au runtime sur Android 6.0+
- Sur iOS/macOS, vérifiez les descriptions d'utilisation

2. ERREUR "SERVICE_NOT_STARTED"

- Vérifiez que le service d'arrière-plan est configuré dans AndroidManifest.xml
- Sur iOS, vérifiez que le mode audio est activé

3. PROBLÈME DE COMPILATION ANDROID

- Vérifiez que le desugaring est correctement configuré
- Assurez-vous que compileSdkVersion est 34 ou supérieur
- Vérifiez que les dépendances androidx sont à jour

4. PERFORMANCE

- Les modèles Whisper sont gourmands en RAM
- Utilisez BackgroundSTTService.getAvailableModels() pour obtenir les modèles compatibles
- BackgroundSTTService.isRamInsufficient() vérifie si le modèle peut être chargé

LIENS UTILES
------------

- flutter_local_notifications: https://pub.dev/packages/flutter_local_notifications
- whisper_ggml: https://pub.dev/packages/whisper_ggml
- record: https://pub.dev/packages/record
- flutter_background_service: https://pub.dev/packages/flutter_background_service
- permission_handler: https://pub.dev/packages/permission_handler

SUPPORT
-------

Pour toute question ou problème, consultez la documentation des packages utilisés ou créez une issue sur le repository du plugin.
