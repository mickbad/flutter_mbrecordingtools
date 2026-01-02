/// MB Recording Tools - Plugin Flutter pour l'enregistrement audio en arrière-plan
///
/// Ce plugin fournit des outils pour :
/// - Enregistrement audio en arrière-plan avec services
/// - Analyse waveform en temps réel
/// - Transcription audio avec Whisper GGML
/// - Détection automatique de RAM et gestion des modèles
library mbrecordingtools;

// Exports pour les services d'enregistrement audio
export 'background_audio.dart';

// Exports pour les services de transcription
export 'background_stt_service.dart';
export 'background_stt_labels.dart';

// Exports pour les composants UI
export 'background_audio_waveform_design.dart';

// Réexport des types principaux des packages externes
export 'package:record/record.dart'
    hide RecordConfig, AudioEncoder, AudioInterruptionMode;
export 'package:whisper_ggml/whisper_ggml.dart' hide WhisperController;
