mbRecordingTools - Plugin Flutter
=================================

Flutter Backgroud Recording and Speech-to-text (locally) 

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

CONFIGURATION APPS
------------------

cf fichier GUIDE_CONFIGURATION_MULTIPLATFORME.md

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
