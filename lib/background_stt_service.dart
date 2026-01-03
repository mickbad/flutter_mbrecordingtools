import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

import 'background_stt_labels.dart';

/// Classe de service pour la reconnaissance vocale (Speech-to-Text) avec Whisper GGML
///
/// Fonctionnalités:
/// - Chargement de modèle avec indicateur de progression
/// - Détection de RAM disponible
/// - Gestion de la liste des modèles selon la RAM
/// - Transcription audio
class BackgroundSTTService {
  BackgroundSTTService._();

  // ===== CONTROLLERS & STREAMS =====
  static final WhisperController _whisperController = WhisperController();
  static final StreamController<Map<String, dynamic>>
      _modelLoadProgressController = StreamController.broadcast();
  static final StreamController<String> _transcriptionController =
      StreamController.broadcast();
  static final StreamController<String> _statusController =
      StreamController.broadcast();

  // ===== STATE =====
  static WhisperModel? _currentModel;
  static bool _isModelLoaded = false;
  static bool _isLoading = false;
  static bool _isTranscribing = false;
  static double? _availableRamGB;
  static String? _currentTranscription;
  static BackgroundSTTLabels _labels = BackgroundSTTLabels();

  // ===== MODEL SIZES =====
  /// Taille des modèles en MB
  static const Map<WhisperModel, int> modelSizes = {
    WhisperModel.tiny: 100, // +25% de marge (75 MB)
    WhisperModel.base: 180, // +25% de marge (142 MB)
    WhisperModel.small: 600, // +25% de marge (466 MB)
    WhisperModel.medium: 1900, // +25% de marge (1500 MB)
    WhisperModel.large: 4000, // +25% de marge (3100 MB)
  };

  // ===== STREAMS =====
  /// Stream pour la progression du chargement du modèle (0.0 à 1.0)
  static Stream<Map<String, dynamic>> get modelLoadProgressStream =>
      _modelLoadProgressController.stream;

  /// Stream pour les transcriptions
  static Stream<String> get transcriptionStream =>
      _transcriptionController.stream;

  /// Stream pour le statut (messages d'état)
  static Stream<String> get statusStream => _statusController.stream;

  // ===== GETTERS =====
  static WhisperModel? get currentModel => _currentModel;
  static bool get isModelLoaded => _isModelLoaded;
  static bool get isLoading => _isLoading;
  static bool get isTranscribing => _isTranscribing;
  static double? get availableRamGB => _availableRamGB;
  static String? get currentTranscription => _currentTranscription;

  // ===== INITIALIZATION =====
  /// Initialise le service et vérifie la RAM disponible
  static Future<void> init({
    BackgroundSTTLabels? labels,
  }) async {
    _labels = labels ?? BackgroundSTTLabels();

    try {
      await _checkDeviceRam();
      _statusController.add(_labels.initializationMessage);
      debugPrint(
          '[BackgroundSTTService] Initialisation réussie - RAM: ${_availableRamGB?.toStringAsFixed(1) ?? 'N/A'} GB');
    } catch (e, stackTrace) {
      debugPrint('[BackgroundSTTService] Erreur lors de l\'initialisation: $e');
      debugPrint('[BackgroundSTTService] Stack trace: $stackTrace');

      // Valeurs par défaut en cas d'erreur
      _availableRamGB = 3.0;
      _statusController.add('Initialisation avec paramètres par défaut');
    }
  }

  // ===== RAM DETECTION =====
  /// Détecte la RAM disponible sur l'appareil
  static Future<void> _checkDeviceRam() async {
    try {
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        await _checkAndroidRam(deviceInfo);
      } else if (Platform.isIOS) {
        await _checkIosRam(deviceInfo);
      } else if (Platform.isMacOS) {
        await _checkMacOsRam(deviceInfo);
      } else if (Platform.isWindows) {
        await _checkWindowsRam(deviceInfo);
      } else if (Platform.isLinux) {
        await _checkLinuxRam(deviceInfo);
      } else {
        _availableRamGB = 4.0;
      }

      debugPrint(
          '[BackgroundSTTService] RAM détectée: ${_availableRamGB?.toStringAsFixed(1)} GB');
    } catch (e) {
      debugPrint('[BackgroundSTTService] Erreur lors de la détection RAM: $e');
      _availableRamGB = 4.0;
    }
  }

  /// Détecte la RAM sur Android
  static Future<void> _checkAndroidRam(DeviceInfoPlugin deviceInfo) async {
    try {
      final androidInfo = await deviceInfo.androidInfo;
      final totalMem = androidInfo.data['totalMemory'] as int? ?? 0;

      if (totalMem > 0) {
        _availableRamGB = totalMem / (1024 * 1024 * 1024);
        debugPrint(
            '[BackgroundSTTService] RAM Android détectée: ${_availableRamGB?.toStringAsFixed(1)} GB (raw: $totalMem bytes)');
      } else {
        // Fallback: estimation basée sur le modèle et la version Android
        _availableRamGB = _estimateAndroidRam(androidInfo.model);
        debugPrint(
            '[BackgroundSTTService] Estimation RAM Android: ${_availableRamGB?.toStringAsFixed(1)} GB');
      }
    } catch (e) {
      debugPrint('[BackgroundSTTService] Erreur Android RAM: $e');
      // Valeur par défaut conservatrice pour éviter les crashs
      _availableRamGB = 3.0;
      debugPrint('[BackgroundSTTService] RAM Android par défaut: 3.0 GB');
    }
  }

  /// Estimation de la RAM basée sur le modèle Android
  static double _estimateAndroidRam(String model) {
    final modelLower = model.toLowerCase();

    // Flagship Android (2020+)
    if (modelLower.contains('galaxy s2') ||
        modelLower.contains('pixel 6') ||
        modelLower.contains('pixel 7') ||
        modelLower.contains('pixel 8') ||
        modelLower.contains('oneplus 9') ||
        modelLower.contains('oneplus 10') ||
        modelLower.contains('xiaomi 12') ||
        modelLower.contains('xiaomi 13')) {
      return 8.0;
    }

    // Mid-range Android (2020+)
    if (modelLower.contains('galaxy a5') ||
        modelLower.contains('pixel 5') ||
        modelLower.contains('oneplus nord') ||
        modelLower.contains('xiaomi redmi')) {
      return 4.0;
    }

    // Budget Android
    if (modelLower.contains('galaxy a1') ||
        modelLower.contains('pixel 4a') ||
        modelLower.contains('moto g') ||
        modelLower.contains('redmi note')) {
      return 3.0;
    }

    // Par défaut pour appareils inconnus
    return 3.0;
  }

  /// Détecte la RAM sur iOS en fonction du modèle
  static Future<void> _checkIosRam(DeviceInfoPlugin deviceInfo) async {
    try {
      final iosInfo = await deviceInfo.iosInfo;
      final model = iosInfo.utsname.machine;
      _availableRamGB = _getIosRamByModel(model);
    } catch (e) {
      debugPrint('[BackgroundSTTService] Erreur iOS RAM: $e');
      _availableRamGB = 3.0;
    }
  }

  /// Retourne la RAM en GB selon le modèle iOS/iPadOS
  static double _getIosRamByModel(String model) {
    // iPhone
    if (model.startsWith('iPhone')) {
      // iPhone 16 series (2024)
      if (model.contains('iPhone17,')) {
        if (model == 'iPhone17,1' || model == 'iPhone17,2') {
          return 8.0; // iPhone 16 Pro/Pro Max
        }
        return 8.0; // iPhone 16/16 Plus
      }

      // iPhone 15 series (2023)
      if (model.contains('iPhone16,')) {
        if (model == 'iPhone16,1' || model == 'iPhone16,2') {
          return 8.0; // iPhone 15 Pro/Pro Max
        }
        return 6.0; // iPhone 15/15 Plus
      }

      // iPhone 14 series (2022)
      if (model.contains('iPhone15,')) {
        if (model == 'iPhone15,2' || model == 'iPhone15,3') {
          return 6.0; // iPhone 14 Pro/Pro Max
        }
        return 6.0; // iPhone 14/14 Plus
      }

      // iPhone 13 series (2021)
      if (model.contains('iPhone14,')) {
        if (model == 'iPhone14,2' || model == 'iPhone14,3') {
          return 6.0; // iPhone 13 Pro/Pro Max
        }
        return 4.0; // iPhone 13/13 mini
      }

      // iPhone 12 series (2020)
      if (model.contains('iPhone13,')) {
        if (model == 'iPhone13,3' || model == 'iPhone13,4') {
          return 6.0; // iPhone 12 Pro/Pro Max
        }
        return 4.0; // iPhone 12/12 mini
      }

      // iPhone 11 series (2019)
      if (model.contains('iPhone12,')) {
        if (model == 'iPhone12,3' || model == 'iPhone12,5') {
          return 4.0; // iPhone 11 Pro/Pro Max
        }
        return 4.0; // iPhone 11
      }

      // iPhone XS/XR series (2018)
      if (model.contains('iPhone11,')) {
        if (model == 'iPhone11,2' ||
            model == 'iPhone11,4' ||
            model == 'iPhone11,6') {
          return 4.0; // XS/XS Max
        }
        return 3.0; // XR
      }

      // iPhone X/8 series (2017)
      if (model.contains('iPhone10,')) {
        if (model == 'iPhone10,3' || model == 'iPhone10,6') {
          return 3.0; // iPhone X
        }
        return 2.0; // iPhone 8/8 Plus
      }

      // iPhone 7 series (2016)
      if (model.contains('iPhone9,')) {
        if (model == 'iPhone9,2' || model == 'iPhone9,4') {
          return 3.0; // iPhone 7 Plus
        }
        return 2.0; // iPhone 7
      }

      // iPhone SE series
      if (model.contains('iPhone8,4')) return 2.0; // iPhone SE (1st gen)
      if (model.contains('iPhone12,8')) return 3.0; // iPhone SE (2nd gen)
      if (model.contains('iPhone14,6')) return 4.0; // iPhone SE (3rd gen)
    }

    // iPad
    if (model.startsWith('iPad')) {
      // iPad Pro
      if (model.contains('iPad13,') || model.contains('iPad14,')) {
        return 8.0; // iPad Pro M1/M2 (2021-2023)
      }

      if (model.contains('iPad8,')) {
        if (model == 'iPad8,5' ||
            model == 'iPad8,6' ||
            model == 'iPad8,7' ||
            model == 'iPad8,8' ||
            model == 'iPad8,11' ||
            model == 'iPad8,12') {
          return 6.0;
        }
        return 4.0;
      }

      // iPad Air
      if (model.contains('iPad13,16') || model.contains('iPad13,17')) {
        return 8.0; // iPad Air M1 (2022)
      }
      if (model.contains('iPad11,')) return 4.0; // iPad Air 3/4

      // iPad mini
      if (model.contains('iPad14,1') || model.contains('iPad14,2')) {
        return 4.0; // iPad mini 6 (2021)
      }
      if (model.contains('iPad11,1') || model.contains('iPad11,2')) {
        return 3.0; // iPad mini 5
      }

      // iPad standard
      if (model.contains('iPad13,18') || model.contains('iPad13,19')) {
        return 4.0; // iPad 10 (2022)
      }
      if (model.contains('iPad12,')) return 3.0; // iPad 9 (2021)
      if (model.contains('iPad11,6') || model.contains('iPad11,7')) {
        return 3.0; // iPad 8 (2020)
      }

      return 4.0; // iPad par défaut
    }

    return 3.0; // Valeur par défaut pour modèles inconnus
  }

  /// Détecte la RAM sur macOS
  static Future<void> _checkMacOsRam(DeviceInfoPlugin deviceInfo) async {
    try {
      final result = await Process.run('sysctl', ['hw.memsize']);
      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        final match = RegExp(r'hw\.memsize:\s*(\d+)').firstMatch(output);
        if (match != null) {
          final bytes = int.parse(match.group(1)!);
          _availableRamGB = bytes / (1024 * 1024 * 1024);
          return;
        }
      }
      _availableRamGB = 8.0; // Valeur par défaut
    } catch (e) {
      debugPrint('[BackgroundSTTService] Erreur macOS RAM: $e');
      _availableRamGB = 8.0;
    }
  }

  /// Détecte la RAM sur Windows
  static Future<void> _checkWindowsRam(DeviceInfoPlugin deviceInfo) async {
    try {
      final result = await Process.run(
        'wmic',
        ['ComputerSystem', 'get', 'TotalPhysicalMemory'],
        runInShell: true,
      );

      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        final lines = output.split('\n');
        for (var line in lines) {
          line = line.trim();
          if (line.isNotEmpty && RegExp(r'^\d+$').hasMatch(line)) {
            final bytes = int.parse(line);
            _availableRamGB = bytes / (1024 * 1024 * 1024);
            return;
          }
        }
      }
      _availableRamGB = 8.0; // Valeur par défaut
    } catch (e) {
      debugPrint('[BackgroundSTTService] Erreur Windows RAM: $e');
      _availableRamGB = 8.0;
    }
  }

  /// Détecte la RAM sur Linux
  static Future<void> _checkLinuxRam(DeviceInfoPlugin deviceInfo) async {
    try {
      final file = File('/proc/meminfo');
      if (await file.exists()) {
        final contents = await file.readAsString();
        final match = RegExp(r'MemTotal:\s*(\d+)\s*kB').firstMatch(contents);
        if (match != null) {
          final kb = int.parse(match.group(1)!);
          _availableRamGB = kb / (1024 * 1024);
          return;
        }
      }
      _availableRamGB = 8.0; // Valeur par défaut
    } catch (e) {
      debugPrint('[BackgroundSTTService] Erreur Linux RAM: $e');
      _availableRamGB = 8.0;
    }
  }

  // ===== MODEL MANAGEMENT =====
  /// Vérifie si un modèle peut être chargé avec la RAM disponible
  static bool canLoadModel(WhisperModel model, {double safetyFactor = 3.0}) {
    final modelSizeMB = modelSizes[model] ?? 0;
    if (_availableRamGB != null && _availableRamGB! > 0 && modelSizeMB > 0) {
      final requiredRam = (modelSizeMB * safetyFactor) / 1024;
      return _availableRamGB! >= requiredRam;
    }
    return false;
  }

  /// Vérifie si la RAM est insuffisante pour un modèle
  static bool isRamInsufficient(WhisperModel model) {
    return !canLoadModel(model);
  }

  /// Retourne les modèles disponibles selon la RAM
  static List<WhisperModel> getAvailableModels() {
    try {
      return WhisperModel.values.where(canLoadModel).toList()
        ..sort((a, b) {
          final sizeA = modelSizes[a] ?? 0;
          final sizeB = modelSizes[b] ?? 0;
          return sizeA.compareTo(sizeB);
        });
    } catch (e) {
      debugPrint(
          '[BackgroundSTTService] Erreur lors de la récupération des modèles disponibles: $e');
      return [];
    }
  }

  /// Retourne le modèle recommandé selon la RAM disponible
  static WhisperModel getRecommendedModel() {
    final availableModels = getAvailableModels();
    if (availableModels.isEmpty) {
      return WhisperModel.tiny;
    }
    return availableModels.last;
  }

  /// Retourne le statut RAM formaté pour l'affichage
  static String getRamStatus(WhisperModel model) {
    final modelSizeMB = modelSizes[model] ?? 0;
    if (_availableRamGB == null || _availableRamGB! <= 0) {
      return _labels.ramNotDetectedMessage;
    }

    final requiredRam = (modelSizeMB * 3) / 1024;
    if (_availableRamGB! >= requiredRam) {
      return _labels.formatMessage(
        _labels.ramSufficientMessage,
        {
          'available': _availableRamGB!.toStringAsFixed(1),
          'required': requiredRam.toStringAsFixed(1)
        },
      );
    } else {
      return _labels.formatMessage(
        _labels.ramInsufficientMessage,
        {
          'available': _availableRamGB!.toStringAsFixed(1),
          'required': requiredRam.toStringAsFixed(1)
        },
      );
    }
  }

  // ===== MODEL LOADING =====
  /// Charge un modèle Whisper avec indicateur de progression
  static Future<bool> loadModel(
    WhisperModel model, {
    bool showProgress = true,
  }) async {
    if (_isLoading) {
      debugPrint(
          '[BackgroundSTTService] Un modèle est déjà en cours de chargement');
      return false;
    }

    if (_isModelLoaded && _currentModel == model) {
      debugPrint(
          '[BackgroundSTTService] Modèle déjà chargé: ${model.modelName}');
      return true;
    }

    _isLoading = true;
    _statusController.add(_labels.formatMessage(
        _labels.modelLoadingMessage, {'model': model.modelName}));

    try {
      // Vérification plus stricte de la RAM avec gestion d'erreur améliorée
      if (isRamInsufficient(model)) {
        final modelSizeMB = modelSizes[model] ?? 0;
        final requiredRam = (modelSizeMB * 3) / 1024;
        final availableRamStr = _availableRamGB?.toStringAsFixed(1) ?? 'N/A';

        final errorMessage = _labels.formatMessage(
          _labels.ramInsufficientMessage,
          {
            'available': availableRamStr,
            'required': requiredRam.toStringAsFixed(1)
          },
        );

        debugPrint('[BackgroundSTTService] $errorMessage');
        throw Exception(errorMessage);
      }

      final modelPath = await _whisperController.getPath(model);
      final exists = await File(modelPath).exists();

      if (exists) {
        _statusController.add(_labels.formatMessage(
            _labels.modelAlreadyPresentMessage, {'model': model.modelName}));
        if (showProgress) {
          _modelLoadProgressController.add({
            'progress': 1.0,
            'speed': 'N/A',
            'timeRemaining': 'N/A',
          });
        }
      } else {
        if (showProgress) {
          _modelLoadProgressController.add({
            'progress': 0.0,
            'speed': '0.0 Mo/s',
            'timeRemaining': '--:--',
          });
        }

        _statusController.add(_labels.formatMessage(
            _labels.modelDownloadMessage, {'model': model.modelName}));

        await downloadModel(
          model,
          onProgress: (progress, speed, timeRemaining) {
            _modelLoadProgressController.add({
              'progress': progress,
              'speed': speed,
              'timeRemaining': timeRemaining,
            });
          },
        );
      }

      _currentModel = model;
      _isModelLoaded = true;
      _isLoading = false;
      _statusController.add(_labels.formatMessage(
          _labels.modelLoadedSuccessMessage, {'model': model.modelName}));

      if (showProgress) {
        _modelLoadProgressController.add({
          'progress': 1.0,
          'speed': 'N/A',
          'timeRemaining': 'N/A',
        });
      }

      debugPrint(
          '[BackgroundSTTService] Modèle ${model.modelName} chargé avec succès');
      return true;
    } catch (e, stackTrace) {
      _isLoading = false;

      final errorMsg = e.toString();
      debugPrint(
          '[BackgroundSTTService] Erreur de chargement du modèle: $errorMsg');
      debugPrint('[BackgroundSTTService] Stack trace: $stackTrace');

      _statusController.add(_labels
          .formatMessage(_labels.modelLoadErrorMessage, {'error': errorMsg}));

      return false;
    }
  }

  ///
  /// Téléchargement du modèle
  ///
  static Future<String> downloadModel(
    WhisperModel model, {
    Function(double progress, String speed, String timeRemaining)? onProgress,
  }) async {
    final request = await HttpClient().getUrl(model.modelUri);
    final response = await request.close();

    final contentLength = response.contentLength;
    final File file = File(await _whisperController.getPath(model));

    int downloadedBytes = 0;
    final sink = file.openWrite();

    final startTime = DateTime.now();
    // int lastBytes = 0;
    DateTime lastTime = startTime;

    try {
      await for (var chunk in response) {
        sink.add(chunk);
        downloadedBytes += chunk.length;

        if (contentLength > 0) {
          final progress = downloadedBytes / contentLength;
          final now = DateTime.now();
          final timeDiff = now.difference(lastTime).inMilliseconds;

          if (timeDiff >= 100) {
            final totalTimeDiff = now.difference(startTime).inMilliseconds;
            final avgSpeed = totalTimeDiff > 0
                ? (downloadedBytes / totalTimeDiff) * 1000
                : 0.0;
            final avgSpeedStr = _formatSpeed(avgSpeed);

            final remainingBytes = contentLength - downloadedBytes;
            final timeRemainingStr = avgSpeed > 0
                ? _formatTimeRemaining(remainingBytes / avgSpeed)
                : '--:--';

            onProgress?.call(progress, avgSpeedStr, timeRemainingStr);

            // lastBytes = downloadedBytes;
            lastTime = now;
          }
        }
      }

      await sink.flush();
    } finally {
      await sink.close();
    }

    onProgress?.call(1.0, '0 o/s', _labels.finished);

    return file.path;
  }

  /// Formate la vitesse en o/s, Ko/s, Mo/s, Go/s
  static String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) {
      return _labels.formatMessage(_labels.unityOctetPerSecond,
          {'speed': bytesPerSecond.toStringAsFixed(0)});
    } else if (bytesPerSecond < 1024 * 1024) {
      return _labels.formatMessage(_labels.unityKiloOctetPerSecond,
          {'speed': (bytesPerSecond / 1024).toStringAsFixed(1)});
    } else if (bytesPerSecond < 1024 * 1024 * 1024) {
      return _labels.formatMessage(_labels.unityMegaOctetPerSecond,
          {'speed': (bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)});
    } else {
      return _labels.formatMessage(_labels.unityGigaOctetPerSecond, {
        'speed': (bytesPerSecond / (1024 * 1024 * 1024)).toStringAsFixed(2)
      });
    }
  }

  /// Formate le temps restant en secondes, minutes, heures
  static String _formatTimeRemaining(double seconds) {
    if (seconds < 60) {
      return '${seconds.toStringAsFixed(0)}s';
    } else if (seconds < 3600) {
      final minutes = seconds / 60;
      return '${minutes.toStringAsFixed(0)}min';
    } else {
      final hours = seconds / 3600;
      final remainingMinutes = (seconds % 3600) / 60;
      return '${hours.toStringAsFixed(0).padLeft(2, '0')}:${remainingMinutes.toStringAsFixed(0).padLeft(2, '0')}';
    }
  }

  /// Décharge le modèle actuel pour libérer de la mémoire
  static Future<void> unloadModel() async {
    if (!_isModelLoaded) return;

    _currentModel = null;
    _isModelLoaded = false;
    _statusController.add(_labels.modelUnloadedMessage);
    debugPrint('[BackgroundSTTService] Modèle déchargé');
  }

  /// Vérifie si le modèle actuel est chargé
  static Future<bool> isCurrentModelLoaded() async {
    if (_currentModel == null) return false;

    try {
      final modelPath = await _whisperController.getPath(_currentModel!);
      return await File(modelPath).exists();
    } catch (e) {
      return false;
    }
  }

  // ===== TRANSCRIPTION =====
  /// Transcrit un fichier audio
  static Future<String?> transcribe({
    required String audioPath,
    String lang = 'auto',
    WhisperModel? model,
  }) async {
    final targetModel = model ?? _currentModel;

    if (targetModel == null) {
      _statusController.add(_labels.noModelSelectedMessage);
      return null;
    }

    if (!_isModelLoaded) {
      _statusController.add(_labels.modelNotLoadedMessage);
      return null;
    }

    _isTranscribing = true;
    _statusController.add(_labels.transcriptionInProgressMessage);

    try {
      _transcriptionController.add('');

      // chronomètre
      final stopwatch = Stopwatch()..start();

      // transcription
      final result = await _whisperController.transcribe(
        model: targetModel,
        audioPath: audioPath,
        lang: lang,
        diarize: false,
      );

      _isTranscribing = false;

      // calcul du temps de transcription en HH:MM:SS.ms
      stopwatch.stop();
      final timeStr = "${stopwatch.elapsed.inHours.toString().padLeft(2, '0')}"
          ":${(stopwatch.elapsed.inMinutes % 60).toString().padLeft(2, '0')}"
          ":${(stopwatch.elapsed.inSeconds % 60).toString().padLeft(2, '0')}"
          ".${stopwatch.elapsed.inMilliseconds}";
      debugPrint('[BackgroundSTTService] Transcription terminée en $timeStr');

      if (result?.transcription.text != null) {
        _currentTranscription = result!.transcription.text;
        _transcriptionController.add(_currentTranscription!);
        _statusController.add(_labels.formatMessage(
            _labels.transcriptionCompletedMessage, {'time': timeStr}));
        return _currentTranscription;
      } else {
        _statusController.add(_labels.formatMessage(
            _labels.transcriptionEmptyMessage, {'time': timeStr}));
        return null;
      }
    } catch (e) {
      _isTranscribing = false;

      // Détecter les erreurs spécifiques de whisper_ggml
      final errorMsg = e.toString();
      if (errorMsg.contains('Assertion failed') ||
          errorMsg.contains('mel_inp.n_mel') ||
          errorMsg.contains('whisper_encode')) {
        final suggestion = _getModelSuggestion(targetModel);
        final userFriendlyError = _labels.formatMessage(
          _labels.transcriptionFailedSuggestionMessage,
          {
            'model': targetModel.modelName,
            'suggestion': suggestion,
          },
        );
        _statusController.add(userFriendlyError);
        debugPrint(
            '[BackgroundSTTService] Erreur de transcription (Assertion failed): $e');
        return null;
      }

      _statusController.add(_labels.formatMessage(
          _labels.transcriptionErrorMessage, {'error': e.toString()}));
      debugPrint('[BackgroundSTTService] Erreur de transcription: $e');
      return null;
    }
  }

  /// Retourne une suggestion de modèle alternatif
  static String _getModelSuggestion(WhisperModel? model) {
    if (model == WhisperModel.large) {
      return _labels.transcriptionSuggestionMessage;
    }
    return _labels.transcriptionCommonSuggestionMessage;
  }

  // ===== UTILITIES =====
  /// Retourne le chemin du fichier modèle
  static Future<String> getModelPath(WhisperModel model) async {
    return await _whisperController.getPath(model);
  }

  /// Vérifie si un modèle existe localement
  static Future<bool> modelExists(WhisperModel model) async {
    try {
      final modelPath = await _whisperController.getPath(model);
      return await File(modelPath).exists();
    } catch (e) {
      return false;
    }
  }

  /// Retourne la liste des modèles téléchargés localement
  static Future<List<WhisperModel>> getDownloadedModels() async {
    final List<WhisperModel> downloadedModels = [];

    for (final model in WhisperModel.values) {
      if (await modelExists(model)) {
        downloadedModels.add(model);
      }
    }

    // Trier par taille pour un affichage logique
    downloadedModels.sort((a, b) {
      final sizeA = modelSizes[a] ?? 0;
      final sizeB = modelSizes[b] ?? 0;
      return sizeA.compareTo(sizeB);
    });

    return downloadedModels;
  }

  /// Supprime un modèle téléchargé
  static Future<bool> deleteModel(WhisperModel model) async {
    try {
      final modelPath = await _whisperController.getPath(model);
      final file = File(modelPath);
      if (await file.exists()) {
        await file.delete();
        if (_currentModel == model) {
          await unloadModel();
        }
        _statusController.add(_labels.formatMessage(
            _labels.modelDeletedMessage, {'model': model.modelName}));
        return true;
      }
      return false;
    } catch (e) {
      _statusController.add(_labels.formatMessage(
          _labels.modelDeleteErrorMessage, {'error': e.toString()}));
      debugPrint('[BackgroundSTTService] Erreur de suppression du modèle: $e');
      return false;
    }
  }

  // ===== DISPOSE =====
  /// Libère les ressources du service
  static Future<void> dispose() async {
    await unloadModel();
    await _modelLoadProgressController.close();
    await _transcriptionController.close();
    await _statusController.close();
    debugPrint('[BackgroundSTTService] BackgroundSTTService disposed');
  }
}

/// Résultat de transcription avec texte et timestamps
class TranscriptionResult {
  final String text;
  final List<Segment> segments;
  final String time;

  TranscriptionResult({
    required this.text,
    required this.segments,
    required this.time,
  });
}

/// Segment de transcription avec timestamps
class Segment {
  final int id;
  final double start;
  final double end;
  final String text;

  Segment({
    required this.id,
    required this.start,
    required this.end,
    required this.text,
  });

  @override
  String toString() {
    return '$text (${start.toStringAsFixed(2)}s - ${end.toStringAsFixed(2)}s)';
  }
}
