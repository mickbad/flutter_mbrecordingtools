import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

// Import du plugin mbrecordingtools
import 'package:mbrecordingtools/mbrecordingtools.dart';

String _formatDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  final hours = twoDigits(duration.inHours);
  final minutes = twoDigits(duration.inMinutes.remainder(60));
  final seconds = twoDigits(duration.inSeconds.remainder(60));
  return duration.inHours > 0
      ? '$hours:$minutes:$seconds'
      : '$minutes:$seconds';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialiser les plugins dans l'ordre approprié
    debugPrint('Initialisation des plugins...');

    // Initialiser d'abord les notifications locales
    debugPrint('1. Initialisation des notifications...');
    await BackgroundAudioService.init();

    // Puis initialiser le service STT
    debugPrint('2. Initialisation du service STT...');
    await BackgroundSTTService.init();

    debugPrint('Tous les plugins initialisés avec succès');
  } catch (e, stackTrace) {
    debugPrint('Erreur lors de l\'initialisation: $e');
    debugPrint('Stack trace: $stackTrace');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recording Ricochets.dev',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  WhisperModel selectedModel = WhisperModel.base;
  final AudioRecorder audioRecorder = AudioRecorder();
  final AudioPlayer audioPlayer = AudioPlayer();

  // Langue sélectionnée
  String _selectedLanguage = 'auto';

  // Fonction pour obtenir l'émoji du drapeau selon la langue
  Widget _getLanguageIcon() {
    switch (_selectedLanguage) {
      case 'auto':
        return const Text('🌍', style: TextStyle(fontSize: 20));
      case 'fr':
        return const Text('🇫🇷', style: TextStyle(fontSize: 20));
      case 'en':
        return const Text('🇺🇸', style: TextStyle(fontSize: 20));
      default:
        return const Icon(Icons.language);
    }
  }

  String instructionsText = "";
  String transcribedText = 'Transcribed text will be displayed here';
  String downloadStatus = "";
  bool isProcessing = false;
  bool isProcessingFile = false;
  bool isListening = false;
  bool showOptionView = true;
  bool isDownloading = false;
  double downloadProgress = 0.0;
  Duration recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<String>? _transcriptionSub;
  StreamSubscription<String>? _statusSub;
  StreamSubscription<Map<String, dynamic>>? _progressSub;

  @override
  void initState() {
    super.initState();

    // après la première frame, vérifier l'état du modèle
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Permissions
      _requestPermissions();

      // Ecouter les flux
      _listenToStreams();
      _checkModelStatus();
    });
  }

  void _listenToStreams() {
    // Écouter le statut du service STT
    _statusSub = BackgroundSTTService.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          instructionsText = status;
        });
      }
    });

    // Écouter le statut du service STT
    _transcriptionSub = BackgroundSTTService.transcriptionStream.listen((
      status,
    ) {
      if (mounted) {
        setState(() {
          transcribedText = status;
        });
      }
    });

    // Écouter la progression du chargement du modèle
    _progressSub = BackgroundSTTService.modelLoadProgressStream.listen((
      Map<String, dynamic> status,
    ) {
      if (mounted) {
        setState(() {
          downloadProgress = status["progress"];
          downloadStatus =
              "${(status["progress"] * 100).toStringAsFixed(1)}%"
              " (${status["speed"]} - remaining ${status["timeRemaining"]})";
        });
      }
    });

    // Écouter la durée d'enregistrement
    _durationSub = BackgroundAudioService.durationStream.listen((duration) {
      if (mounted) {
        setState(() {
          recordingDuration = duration;
        });
      }
    });
  }

  Future<void> _checkModelStatus() async {
    // chargement du modèle par défaut
    if (BackgroundSTTService.currentModel == null) {
      setState(() {
        isDownloading = true;
      });

      await BackgroundSTTService.loadModel(selectedModel);

      setState(() {
        isDownloading = false;
      });
    }

    // vérification de l'état du modèle
    final isLoaded = await BackgroundSTTService.isCurrentModelLoaded();
    if (mounted) {
      setState(() {
        if (isLoaded) {
          instructionsText =
              'Model ${selectedModel.modelName} ready. Press the microphone to record.';
        } else {
          instructionsText =
              'Model ${selectedModel.modelName} not found. Please download it.';
        }
      });
    }
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    _recordingTimer?.cancel();
    _durationSub?.cancel();
    _statusSub?.cancel();
    _transcriptionSub?.cancel();
    _progressSub?.cancel();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    try {
      final List<Permission> permissions = [];

      /// Microphone
      if (Platform.isAndroid || Platform.isWindows || Platform.isMacOS) {
        permissions.add(Permission.microphone);
      }

      /// Photos (iOS uniquement si nécessaire)
      // if (Platform.isIOS) {
      //   permissions.add(Permission.photos);
      // }

      /// Notifications (Android 13+ uniquement)
      if (Platform.isAndroid) {
        permissions.add(Permission.notification);
      }

      if (permissions.isEmpty) {
        debugPrint('Aucune permission requise sur cette plateforme');
        return;
      }

      /// Demande des permissions
      final statuses = await permissions.request();

      bool allGranted = true;
      for (final entry in statuses.entries) {
        final permission = entry.key;
        final status = entry.value;

        debugPrint('${permission.toString()} → $status');

        if (!status.isGranted && !status.isLimited) {
          allGranted = false;
        }
      }

      /// Permission bloquée définitivement
      final hasPermanentlyDenied = statuses.values.any(
        (status) => status.isPermanentlyDenied,
      );

      if (!allGranted && hasPermanentlyDenied) {
        await openAppSettings();
      }
    } catch (e) {
      debugPrint('Erreur lors de la demande de permissions: $e');
    }
  }

  void _showModelNotLoadedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modèle non chargé'),
        content: const Text(
          'Veuillez d\'abord télécharger le modèle Whisper dans les paramètres.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showRamInsufficientDialog(WhisperModel model) {
    final modelSizeMB = BackgroundSTTService.modelSizes[model] ?? 0;
    final requiredRam = (modelSizeMB * 3) / 1024;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Mémoire insuffisante'),
        content: Text(
          'Le modèle ${model.modelName} nécessite environ ${requiredRam.toStringAsFixed(1)}GB de RAM, '
          'mais votre appareil n\'a pas assez de mémoire. '
          'Veuillez sélectionner un modèle plus petit (tiny, base ou small).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final availableModels = BackgroundSTTService.getAvailableModels();
    final isRamInsufficient = BackgroundSTTService.isRamInsufficient(
      selectedModel,
    );
    final isModelLoaded = BackgroundSTTService.isModelLoaded;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Recording Ricochets.dev'),
        actions: [
          // langue
          PopupMenuButton<String>(
            icon: _getLanguageIcon(),
            tooltip: "Select your language spoken",
            onSelected: (lang) {
              setState(() {
                _selectedLanguage = lang;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'auto',
                child: Row(spacing: 8, children: [Text('🌍'), Text('auto')]),
              ),
              const PopupMenuItem(
                value: 'fr',
                child: Row(
                  spacing: 8,
                  children: [Text('🇫🇷'), Text('french')],
                ),
              ),
              const PopupMenuItem(
                value: 'en',
                child: Row(
                  spacing: 8,
                  children: [Text('🇺🇸'), Text('english')],
                ),
              ),
            ],
          ),

          // modèles
          PopupMenuButton<WhisperModel>(
            icon: const Icon(Icons.model_training),
            tooltip: "Select your spoken model",
            onSelected: (model) async {
              if (BackgroundSTTService.isRamInsufficient(model)) {
                _showRamInsufficientDialog(model);
                return;
              }

              // déchargement
              await BackgroundSTTService.unloadModel();

              setState(() {
                selectedModel = model;
                isDownloading = true;
                downloadStatus = 'Téléchargement...';
              });

              await BackgroundSTTService.loadModel(model);
              _checkModelStatus();

              setState(() {
                isDownloading = false;
              });
            },
            itemBuilder: (context) => availableModels.map((model) {
              final sizeMB = BackgroundSTTService.modelSizes[model] ?? 0;
              final canLoad = BackgroundSTTService.canLoadModel(model);
              final isInsufficient = BackgroundSTTService.isRamInsufficient(
                model,
              );

              return PopupMenuItem(
                value: model,
                enabled: canLoad && !isInsufficient,
                child: Row(
                  children: [
                    Text(model.modelName),
                    const SizedBox(width: 8),
                    Text('($sizeMB MB)', style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    if (isInsufficient)
                      const Icon(Icons.warning, color: Colors.red, size: 16),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    color:
                        (BackgroundSTTService.availableRamGB == null ||
                            BackgroundSTTService.availableRamGB! <= 0 ||
                            isRamInsufficient)
                        ? Colors.red.shade50
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Model: ${selectedModel.modelName} (${BackgroundSTTService.modelSizes[selectedModel]} MB)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                isModelLoaded
                                    ? Icons.check_circle
                                    : Icons.warning,
                                color: isModelLoaded
                                    ? Colors.green
                                    : Colors.orange,
                                size: 16,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            BackgroundSTTService.getRamStatus(selectedModel),
                            style: TextStyle(
                              color: isRamInsufficient ? Colors.red : null,
                              fontWeight: isRamInsufficient
                                  ? FontWeight.bold
                                  : null,
                            ),
                          ),
                          if (!isModelLoaded && !BackgroundSTTService.isLoading)
                            const Text(
                              '⚠️ Model unloaded - Use menu to download a new model',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                              ),
                            ),
                          if (isDownloading)
                            Column(
                              children: [
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: downloadProgress,
                                ),
                                Text(downloadStatus),
                              ],
                            ),
                          if (isListening) ...[
                            Text(
                              'Duration: ${_formatDuration(recordingDuration)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            if (showOptionView) ...[
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8.0,
                                runSpacing: 8.0,
                                children: [
                                  // waveform instantanée
                                  Container(
                                    height: 100,
                                    padding: EdgeInsets.all(8.0),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: BackgroundAudioLiveWaveform(
                                        colorStart: Colors.blueAccent.shade100,
                                        color: Colors.blue.shade700,
                                        colorEnd: Colors.blueAccent.shade100,
                                        countBar: 30,
                                      ),
                                    ),
                                  ),

                                  // waveform historique
                                  Container(
                                    height: 100,
                                    padding: EdgeInsets.all(8.0),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child:
                                          BackgroundAudioLiveHistoricWaveform(
                                            colorStart: Colors.redAccent,
                                            color: Colors.purpleAccent,
                                            colorEnd: Colors.blueAccent,
                                            countBar: 30,
                                          ),
                                    ),
                                  ),

                                  // jauge simple
                                  Container(
                                    width: 55,
                                    height: 26,
                                    padding: EdgeInsets.all(8.0),

                                    child: BackgroundAudioLiveSingleWaveform(
                                      colorStart: Colors.blueAccent.shade700,
                                      color: Colors.purpleAccent,
                                      colorEnd: Colors.blueAccent.shade200,
                                      orientation:
                                          WaveformOrientation.horizontal,
                                      animationDurationMs: 25,
                                    ),
                                  ),

                                  // jauge simple
                                  Container(
                                    width: 30,
                                    height: 100,
                                    padding: EdgeInsets.all(8.0),

                                    child: BackgroundAudioLiveSingleWaveform(
                                      colorStart: Colors.redAccent,
                                      color: Colors.purpleAccent,
                                      colorEnd: Colors.blueAccent,
                                      orientation: WaveformOrientation.vertical,
                                    ),
                                  ),

                                  // jauge simple plus réactif
                                  Container(
                                    width: 30,
                                    height: 100,
                                    padding: EdgeInsets.all(8.0),

                                    child: BackgroundAudioLiveSingleWaveform(
                                      colorStart: Colors.redAccent,
                                      color: Colors.purpleAccent,
                                      colorEnd: Colors.blueAccent,
                                      orientation: WaveformOrientation.vertical,
                                      animationDurationMs: 25,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Switch(
                        value: showOptionView,
                        onChanged: (value) {
                          setState(() {
                            showOptionView = value;
                          });
                        },
                      ),
                      const Text('Display waveform'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    instructionsText,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        transcribedText,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                bottom: 24,
                left: 0,
                child: Tooltip(
                  message: 'Transcribe jfk.wav asset file',
                  child: CircleAvatar(
                    backgroundColor: isModelLoaded
                        ? Colors.purple.shade100
                        : Colors.grey.shade300,
                    maxRadius: 25,
                    child: isProcessingFile
                        ? const CircularProgressIndicator()
                        : IconButton(
                            onPressed: isModelLoaded ? transcribeJfk : null,
                            icon: const Icon(Icons.folder),
                            color: isModelLoaded ? null : Colors.grey,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isModelLoaded ? record : null,
        tooltip: isModelLoaded ? 'Start listening' : 'Modèle requis',
        backgroundColor: isModelLoaded ? null : Colors.grey.shade300,
        child: isProcessing
            ? const CircularProgressIndicator()
            : Icon(
                BackgroundAudioService.isRecording ? Icons.mic_off : Icons.mic,
                color: BackgroundAudioService.isRecording
                    ? Colors.red
                    : (isModelLoaded ? null : Colors.grey),
              ),
      ),
    );
  }

  Future<void> record() async {
    if (!BackgroundSTTService.isModelLoaded) {
      _showModelNotLoadedDialog();
      return;
    }

    if (BackgroundAudioService.isRecording) {
      final audioPath = await BackgroundAudioService.stop();
      debugPrint('Saved: $audioPath');

      if (audioPath != null) {
        debugPrint('Stopped listening.');

        setState(() {
          isListening = false;
          isProcessing = true;
        });

        await audioPlayer.stop();
        audioPlayer.play(DeviceFileSource(audioPath));

        try {
          final result = await BackgroundSTTService.transcribe(
            audioPath: audioPath,
            lang: _selectedLanguage,
          );

          if (mounted) {
            setState(() {
              isProcessing = false;
            });
          }

          if (result != null) {
            setState(() {
              transcribedText = result;
            });
          }
        } catch (e) {
          debugPrint('Erreur de transcription: $e');
          if (mounted) {
            setState(() {
              isProcessing = false;
              transcribedText = 'Erreur de transcription: $e';
            });
          }
        } finally {
          await audioPlayer.stop();
          await File(audioPath).delete();
        }
      } else {
        debugPrint('No recording exists.');
      }
    } else {
      final success = await BackgroundAudioService.start();
      debugPrint("Started recording: $success");

      setState(() {
        isListening = true;
      });
    }
  }

  Future<void> transcribeJfk() async {
    if (!BackgroundSTTService.isModelLoaded) {
      _showModelNotLoadedDialog();
      return;
    }

    final Directory tempDir = await getTemporaryDirectory();
    final asset = await rootBundle.load('assets/jfk.wav');
    final String jfkPath = "${tempDir.path}/jfk.wav";
    final File convertedFile = await File(
      jfkPath,
    ).writeAsBytes(asset.buffer.asUint8List());

    setState(() {
      isProcessingFile = true;
    });

    try {
      final result = await BackgroundSTTService.transcribe(
        audioPath: convertedFile.path,
        lang: _selectedLanguage,
      );

      setState(() {
        isProcessingFile = false;
      });

      if (result != null) {
        setState(() {
          transcribedText = result;
        });
      }
    } catch (e) {
      setState(() {
        isProcessingFile = false;
        transcribedText = 'Erreur: $e';
      });
    }
  }
}
