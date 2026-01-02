import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

@pragma('vm:entry-point')
class BackgroundAudioService {
  BackgroundAudioService._();

  static final AudioRecorder _recorder = AudioRecorder();
  static final StreamController<double> _amplitudeController =
      StreamController.broadcast();

  static bool _isRecording = false;
  static StreamSubscription<Amplitude>? _amplitudeSub;
  static String? _currentPath;
  static bool _isBackgroundServiceActive = false;
  static bool _isBackgroundEnabled = false;

  // Timer pour la durée d'enregistrement
  static Duration _recordingDuration = Duration.zero;
  static Timer? _durationTimer;
  static final StreamController<Duration> _durationController =
      StreamController.broadcast();

  // ===== STREAM WAVEFORM =====
  static Stream<double> get waveformStream => _amplitudeController.stream;
  static bool get isRecording => _isRecording;
  static bool get isBackgroundServiceActive => _isBackgroundServiceActive;
  static bool get isBackgroundEnabled => _isBackgroundEnabled;
  static Stream<Duration> get durationStream => _durationController.stream;
  static Duration get recordingDuration => _recordingDuration;

  // ===== INIT =====
  static Future<void> init() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    try {
      debugPrint('[BackgroundAudioService] Début de l\'initialisation');

      // Initialiser flutter_local_notifications côté UI isolate avec gestion d'erreur
      final FlutterLocalNotificationsPlugin notifications =
          FlutterLocalNotificationsPlugin();

      const AndroidInitializationSettings androidInit =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initSettings =
          InitializationSettings(android: androidInit);

      // Initialisation avec gestion d'erreur
      try {
        await notifications.initialize(
          initSettings,
          onDidReceiveNotificationResponse: (NotificationResponse response) {
            debugPrint(
                '[BackgroundAudioService] Notification tap: ${response.payload}');
          },
        );
        debugPrint(
            '[BackgroundAudioService] Notifications initialisées avec succès');
      } catch (e) {
        debugPrint(
            '[BackgroundAudioService] Erreur lors de l\'initialisation des notifications: $e');
        // Continuer même si les notifications échouent
      }

      // Créer le canal de notification Android avec gestion d'erreur
      try {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'audio_recording_channel',
          'Enregistrement Audio',
          description:
              'Notification pour l\'enregistrement audio en arrière-plan',
          importance: Importance.low,
          showBadge: false,
        );

        await notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
        debugPrint('[BackgroundAudioService] Canal de notification créé');
      } catch (e) {
        debugPrint(
            '[BackgroundAudioService] Erreur lors de la création du canal: $e');
        // Continuer même si le canal échoue
      }

      // Configurer le service d'arrière-plan avec gestion d'erreur
      try {
        await FlutterBackgroundService().configure(
          androidConfiguration: AndroidConfiguration(
            onStart: _onBackgroundServiceStart,
            isForegroundMode: true,
            autoStart: false,
            autoStartOnBoot: false,
            notificationChannelId: 'audio_recording_channel',
            initialNotificationTitle: 'Enregistrement en cours',
            initialNotificationContent: 'Enregistrement audio actif',
            foregroundServiceNotificationId: 888,
            foregroundServiceTypes: [AndroidForegroundType.microphone],
          ),
          iosConfiguration: IosConfiguration(
            onForeground: _onBackgroundServiceStart,
            onBackground: _onIosBackground,
            autoStart: false,
          ),
        );
        debugPrint(
            '[BackgroundAudioService] Service d\'arrière-plan configuré');
      } catch (e) {
        debugPrint(
            '[BackgroundAudioService] Erreur lors de la configuration du service: $e');
        // Continuer même si la configuration échoue
      }

      debugPrint('[BackgroundAudioService] Initialisation terminée');
    } catch (e, stackTrace) {
      debugPrint(
          '[BackgroundAudioService] Erreur générale lors de l\'initialisation: $e');
      debugPrint('[BackgroundAudioService] Stack trace: $stackTrace');
    }
  }

  // ===== START BACKGROUND SERVICE =====
  static Future<bool> startBackgroundService() async {
    if (_isBackgroundServiceActive) {
      debugPrint('[BackgroundAudioService] Background service already active');
      return false;
    }

    try {
      final service = FlutterBackgroundService();
      await service.startService();
      _isBackgroundServiceActive = true;
      debugPrint(
          '[BackgroundAudioService] Background service started (no foreground mode)');
      return true;
    } catch (e) {
      debugPrint(
          '[BackgroundAudioService] Error starting background service: $e');
      return false;
    }
  }

  // ===== STOP BACKGROUND SERVICE =====
  static Future<bool> stopBackgroundService() async {
    if (!_isBackgroundServiceActive) {
      debugPrint('[BackgroundAudioService] Background service not active');
      return false;
    }

    try {
      final service = FlutterBackgroundService();
      service.invoke('stop');
      _isBackgroundServiceActive = false;
      debugPrint('[BackgroundAudioService] Background service stopped');
      return true;
    } catch (e) {
      debugPrint(
          '[BackgroundAudioService] Error stopping background service: $e');
      return false;
    }
  }

  // ===== START RECORDING =====
  static Future<bool> start({bool enableBackground = true}) async {
    if (_isRecording) {
      debugPrint(
          '[BackgroundAudioService] Already recording, ignoring start request');
      return false;
    }

    _isBackgroundEnabled = enableBackground;
    debugPrint(
        '[BackgroundAudioService] Background service enabled: $enableBackground');

    // Démarrer le service background si demandé
    if (enableBackground) {
      await startBackgroundService();
    }

    // Vérifier les permissions avec gestion d'erreur
    try {
      final hasPermission = await _recorder.hasPermission();
      debugPrint(
          '[BackgroundAudioService] Microphone permission: $hasPermission');

      if (!hasPermission) {
        debugPrint('[BackgroundAudioService] Microphone permission denied');
        throw Exception('Microphone permission denied');
      }
    } catch (e) {
      debugPrint(
          '[BackgroundAudioService] Erreur lors de la vérification des permissions: $e');
      throw Exception('Permission check failed: $e');
    }

    // Obtenir le répertoire de stockage
    try {
      final dir = await getTemporaryDirectory();
      _currentPath = '${dir.path}/recording-${Uuid().v4()}.m4a';
      debugPrint('[BackgroundAudioService] Recording path: $_currentPath');
    } catch (e) {
      debugPrint(
          '[BackgroundAudioService] Erreur lors de l\'obtention du répertoire: $e');
      throw Exception('Directory access failed: $e');
    }

    // Configurer l'enregistrement avec paramètres plus compatibles
    final config = const RecordConfig(
      encoder: AudioEncoder.aacLc,
      sampleRate: 44100,
      numChannels: 1,
      audioInterruption: AudioInterruptionMode.pauseResume,
      bitRate: 128000, // bitrate explicite
      //sampleRate: 16000, // Réduire pour plus de compatibilité
    );

    // Démarrer l'enregistrement avec gestion d'erreur améliorée
    try {
      debugPrint(
          '[BackgroundAudioService] Tentative de démarrage de l\'enregistrement...');

      await _recorder.start(
        config,
        path: _currentPath!,
      );
      debugPrint('[BackgroundAudioService] Recording start command sent');

      // Vérifier que l'enregistrement a réellement commencé avec plus de délai
      await Future.delayed(const Duration(milliseconds: 500));
      final isActuallyRecording = await _recorder.isRecording();
      debugPrint(
          '[BackgroundAudioService] Recording actually started: $isActuallyRecording');

      if (!isActuallyRecording) {
        debugPrint('[BackgroundAudioService] Recording did not start properly');
        _isRecording = false;
        return false;
      }

      // Démarrer l'écoute de l'amplitude
      _listenAmplitude();
      _isRecording = true;

      // Démarrer le compteur de durée
      _startDurationTimer();

      debugPrint('[BackgroundAudioService] Enregistrement démarré avec succès');
      return true;
    } catch (e, stackTrace) {
      debugPrint('[BackgroundAudioService] Erreur lors du démarrage: $e');
      debugPrint('[BackgroundAudioService] Stack trace: $stackTrace');
      _isRecording = false;

      // Tenter une approche de fallback avec des paramètres plus simples
      try {
        debugPrint(
            '[BackgroundAudioService] Tentative avec paramètres de fallback...');
        final fallbackConfig = const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 8000,
          numChannels: 1,
        );

        await _recorder.start(fallbackConfig, path: _currentPath!);
        await Future.delayed(const Duration(milliseconds: 300));
        final isRecordingFallback = await _recorder.isRecording();

        if (isRecordingFallback) {
          debugPrint(
              '[BackgroundAudioService] Enregistrement démarré avec paramètres de fallback');
          _listenAmplitude();
          _isRecording = true;
          _startDurationTimer();
          return true;
        }
      } catch (fallbackError) {
        debugPrint(
            '[BackgroundAudioService] Erreur également avec les paramètres de fallback: $fallbackError');
      }

      return false;
    }
  }

  // ===== STOP RECORDING =====
  static Future<String?> stop() async {
    if (!_isRecording) return null;

    debugPrint('[BackgroundAudioService] Stopping recording...');

    try {
      // Annuler la subscription d'amplitude d'abord
      await _amplitudeSub?.cancel();
      _amplitudeSub = null;

      // Arrêter l'enregistrement
      final path = await _recorder.stop();
      debugPrint('[BackgroundAudioService] Recording stopped, file: $path');

      // Vérifier que le fichier existe et a du contenu
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          final length = await file.length();
          debugPrint('[BackgroundAudioService] File size: $length bytes');
          if (length == 0) {
            debugPrint('[BackgroundAudioService] WARNING: File is empty!');
          }
        }
      }

      // Réinitialiser l'amplitude
      _amplitudeController.add(0);

      // Arrêter le compteur de durée
      _stopDurationTimer();

      // Arrêter le service background si il était activé
      if (_isBackgroundEnabled) {
        await stopBackgroundService();
      }

      _isRecording = false;
      _currentPath = null;
      _isBackgroundEnabled = false;
      return path;
    } catch (e) {
      debugPrint('[BackgroundAudioService] Error stopping recording: $e');
      _isRecording = false;
      return null;
    }
  }

  // ===== PAUSE =====
  static Future<void> pause() async {
    if (!_isRecording) return;
    try {
      await _recorder.pause();
      debugPrint('[BackgroundAudioService] Recording paused');
    } catch (e) {
      debugPrint('[BackgroundAudioService] Error pausing recording: $e');
    }
  }

  // ===== RESUME =====
  static Future<void> resume() async {
    if (!_isRecording) return;
    try {
      await _recorder.resume();
      debugPrint('[BackgroundAudioService] Recording resumed');
    } catch (e) {
      debugPrint('[BackgroundAudioService] Error resuming recording: $e');
    }
  }

  // ===== CHECK RECORDING STATUS =====
  static Future<bool> checkRecordingStatus() async {
    return await _recorder.isRecording();
  }

  // ===== GET AMPLITUDE =====
  static Future<Amplitude> getAmplitude() async {
    return await _recorder.getAmplitude();
  }

  // ===== LISTEN AMPLITUDE =====
  static void _listenAmplitude() {
    // Réinitialiser la subscription précédente
    _amplitudeSub?.cancel();

    _amplitudeSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 100))
        .listen((amp) {
      if (!_isRecording) return;

      // borne inférieure de l'amplitude
      const double minAmplitude = 65.0;

      // L'amplitude du package record est normalisée entre [-minAmplitude] (silence) et 0 (max)
      double normalized;

      if (amp.current < -minAmplitude) {
        // Silence ou valeur invalide
        normalized = 0.0;
      } else if (amp.current >= 0) {
        // Son très fort
        normalized = 1.0;
      } else {
        // Convertir de [minAmplitude, 0] à [0, 1]
        normalized = (amp.current + minAmplitude) / (minAmplitude);
        normalized = normalized.clamp(0.0, 1.0);
      }

      if (kDebugMode) {
        debugPrint(
            "[BackgroundAudioService] Amplitude raw: ${amp.current}, normalized: $normalized");
      }

      // Si l'amplitude est constamment -120 ou très faible, il y a un problème
      if (amp.current < -100 && amp.current > -1000) {
        debugPrint(
            '[BackgroundAudioService] WARNING: Very low amplitude detected, possible mic issue');
      }

      _amplitudeController.add(normalized);
    });

    debugPrint('[BackgroundAudioService] Amplitude listener started');
  }

  // ===== DURATION TIMER =====
  static void _startDurationTimer() {
    _recordingDuration = Duration.zero;
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _recordingDuration += const Duration(seconds: 1);
      _durationController.add(_recordingDuration);
    });
    debugPrint('[BackgroundAudioService] Duration timer started');
  }

  static void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
    debugPrint('[BackgroundAudioService] Duration timer stopped');
  }

  // ===== DISPOSE =====
  static Future<void> dispose() async {
    if (_isRecording) {
      await stop();
    }
    await _amplitudeController.close();
    await _amplitudeSub?.cancel();
  }

  // ===== GET CURRENT PATH =====
  static String? getCurrentPath() => _currentPath;
}

// ===== BACKGROUND SERVICE CALLBACK =====
@pragma('vm:entry-point')
void _onBackgroundServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  debugPrint('[BackgroundAudioService] Background service started');

  service.on('stop').listen((event) {
    debugPrint('[BackgroundAudioService] Background service stop requested');
    service.stopSelf();
  });

  debugPrint('[BackgroundAudioService] Background service running');
}

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  return true;
}
