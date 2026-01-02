/// Gestion des textes à traduire pour BackgroundSTTService
class BackgroundSTTLabels {
  // Initialization messages
  String initializationMessage = "STT service initialized";

  // Model loading messages
  String modelLoadingMessage = "Loading model {model}...";
  String modelAlreadyPresentMessage = "Model {model} already present";
  String modelDownloadMessage = "Downloading model {model}...";
  String modelLoadedSuccessMessage = "Model {model} loaded successfully";
  String modelUnloadedMessage = "Model unloaded";

  // Transcription messages
  String transcriptionInProgressMessage = "Transcription in progress...";
  String transcriptionCompletedMessage = "Transcription completed in {time}";
  String transcriptionEmptyMessage = "Empty or failed transcription in {time}";
  String transcriptionFailedSuggestionMessage =
      'Erreur de transcription avec le modèle {model}.\n\n'
      'Ceci est un problème de compatibilité du format audio avec le modèle.\n\n'
      '{suggestion}';
  String transcriptionSuggestionMessage = 'Suggestions:\n'
      '- Utilisez le modèle "medium" ou "small" à la place\n'
      '- Vérifiez que le fichier audio est en 16kHz, mono, 16-bit PCM\n'
      '- Signalez ce bug aux développeurs';
  String transcriptionCommonSuggestionMessage =
      "Veuillez réessayer avec un autre modèle ou vérifier le format audio.";

  String noModelSelectedMessage = "No model selected";
  String modelNotLoadedMessage = "Model not loaded";
  String transcriptionErrorMessage = "Transcription error: {error}";

  // Error messages
  String modelLoadErrorMessage = "Loading error: {error}";
  String ramSufficientMessage =
      "RAM: {available}GB available, required: ~{required}GB";
  String ramInsufficientMessage =
      "Insufficient RAM: {available}GB available, required: ~{required}GB";
  String modelDeletedMessage = "Model {model} deleted";
  String modelDeleteErrorMessage = "Deletion error: {error}";

  // Generic status messages
  String loadingMessage = "Loading...";
  String completedMessage = "Completed";
  String ramNotDetectedMessage = "⚠️ RAM: Not detected";
  String modelNotLoadedWarningMessage =
      "⚠️ Model not loaded - Use the menu to download";

  String finished = "Finished";
  String unityOctetPerSecond = "{speed} Bytes/s";
  String unityKiloOctetPerSecond = "{speed} KB/s";
  String unityMegaOctetPerSecond = "{speed} MB/s";
  String unityGigaOctetPerSecond = "{speed} GB/s";

  BackgroundSTTLabels();

  /// Constructeur de copie
  BackgroundSTTLabels copyWith({
    String? initializationMessage,
    String? modelLoadingMessage,
    String? modelAlreadyPresentMessage,
    String? modelDownloadMessage,
    String? modelLoadedSuccessMessage,
    String? modelUnloadedMessage,
    String? transcriptionInProgressMessage,
    String? transcriptionCompletedMessage,
    String? transcriptionEmptyMessage,
    String? transcriptionFailedSuggestionMessage,
    String? transcriptionSuggestionMessage,
    String? transcriptionCommonSuggestionMessage,
    String? noModelSelectedMessage,
    String? modelNotLoadedMessage,
    String? transcriptionErrorMessage,
    String? modelLoadErrorMessage,
    String? ramInsufficientMessage,
    String? ramSufficientMessage,
    String? modelDeletedMessage,
    String? modelDeleteErrorMessage,
    String? loadingMessage,
    String? completedMessage,
    String? ramNotDetectedMessage,
    String? modelNotLoadedWarningMessage,
    String? finished,
    String? unityOctetPerSecond,
    String? unityKiloOctetPerSecond,
    String? unityMegaOctetPerSecond,
    String? unityGigaOctetPerSecond,
  }) {
    return BackgroundSTTLabels()
      ..initializationMessage =
          initializationMessage ?? this.initializationMessage
      ..modelLoadingMessage = modelLoadingMessage ?? this.modelLoadingMessage
      ..modelAlreadyPresentMessage =
          modelAlreadyPresentMessage ?? this.modelAlreadyPresentMessage
      ..modelDownloadMessage = modelDownloadMessage ?? this.modelDownloadMessage
      ..modelLoadedSuccessMessage =
          modelLoadedSuccessMessage ?? this.modelLoadedSuccessMessage
      ..modelUnloadedMessage = modelUnloadedMessage ?? this.modelUnloadedMessage
      ..transcriptionInProgressMessage =
          transcriptionInProgressMessage ?? this.transcriptionInProgressMessage
      ..transcriptionCompletedMessage =
          transcriptionCompletedMessage ?? this.transcriptionCompletedMessage
      ..transcriptionEmptyMessage =
          transcriptionEmptyMessage ?? this.transcriptionEmptyMessage
      ..transcriptionFailedSuggestionMessage =
          transcriptionFailedSuggestionMessage ??
              this.transcriptionFailedSuggestionMessage
      ..transcriptionSuggestionMessage =
          transcriptionSuggestionMessage ?? this.transcriptionSuggestionMessage
      ..transcriptionCommonSuggestionMessage =
          transcriptionCommonSuggestionMessage ??
              this.transcriptionCommonSuggestionMessage
      ..noModelSelectedMessage =
          noModelSelectedMessage ?? this.noModelSelectedMessage
      ..modelNotLoadedMessage =
          modelNotLoadedMessage ?? this.modelNotLoadedMessage
      ..transcriptionErrorMessage =
          transcriptionErrorMessage ?? this.transcriptionErrorMessage
      ..modelLoadErrorMessage =
          modelLoadErrorMessage ?? this.modelLoadErrorMessage
      ..ramInsufficientMessage =
          ramInsufficientMessage ?? this.ramInsufficientMessage
      ..ramSufficientMessage = ramSufficientMessage ?? this.ramSufficientMessage
      ..modelDeletedMessage = modelDeletedMessage ?? this.modelDeletedMessage
      ..modelDeleteErrorMessage =
          modelDeleteErrorMessage ?? this.modelDeleteErrorMessage
      ..loadingMessage = loadingMessage ?? this.loadingMessage
      ..completedMessage = completedMessage ?? this.completedMessage
      ..ramNotDetectedMessage =
          ramNotDetectedMessage ?? this.ramNotDetectedMessage
      ..modelNotLoadedWarningMessage =
          modelNotLoadedWarningMessage ?? this.modelNotLoadedWarningMessage
      ..finished = finished ?? this.finished
      ..unityOctetPerSecond = unityOctetPerSecond ?? this.unityOctetPerSecond
      ..unityKiloOctetPerSecond =
          unityKiloOctetPerSecond ?? this.unityKiloOctetPerSecond
      ..unityMegaOctetPerSecond =
          unityMegaOctetPerSecond ?? this.unityMegaOctetPerSecond
      ..unityGigaOctetPerSecond =
          unityGigaOctetPerSecond ?? this.unityGigaOctetPerSecond;
  }

  /// Formatte un message avec des paramètres
  String formatMessage(String template, Map<String, dynamic> parameters) {
    String result = template;
    parameters.forEach((key, value) {
      result = result.replaceAll('{$key}', value.toString());
    });
    return result;
  }
}
