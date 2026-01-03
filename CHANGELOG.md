## 1.0.0

### ✨ Nouvelles Fonctionnalités

- **Service de Reconnaissance Vocale (STT) Complet**
  - Intégration de Whisper GGML pour la transcription audio en temps réel
  - Support multi-modèles : tiny, base, small, medium, large
  - Détection automatique de RAM par plateforme pour optimiser le choix du modèle
  - Téléchargement automatique des modèles avec indicateur de progression
  - Gestion intelligente des modèles (chargement, déchargement, suppression)

- **Détection Automatique de RAM par Plateforme**
  - Android : Détection directe via DeviceInfoPlugin avec fallback intelligent
  - iOS : Support complet de tous les modèles iPhone/iPad (iPhone 16, 15, 14, 13, 12, 11, XS/XR, X/8, 7, SE)
  - macOS : Détection via sysctl hw.memsize
  - Windows : Utilisation de WMIC pour la détection physique
  - Linux : Lecture de /proc/meminfo

- **Widgets Waveform Améliorés**
  - `BackgroundAudioLiveWaveform` : Waveform en temps réel avec dégradés 3 couleurs
  - `BackgroundAudioLiveHistoricWaveform` : Waveform avec historique des données
  - `BackgroundAudioWaveformBar` : Barres individuelles avec variations animées
  - Support des dégradés colorStart → color → colorEnd
  - Animations fluides et personnalisables

- **Interface Utilisateur Complète**
  - Sélecteur de langue (auto, français, anglais) avec drapeaux
  - Gestionnaire de modèles avec informations de taille et statut RAM
  - Indicateurs visuels de progression et statut
  - Support des permissions multiplateformes
  - Transcription d'exemples audio (jfk.wav)

### 🎯 Fonctionnalités Avancées
- Transcription temps réel avec chronométrage précis
- Gestion des erreurs spécifiques Whisper avec suggestions
- Interface responsive avec Material Design 3
- Support des formats audio multiples
- Système de notifications en arrière-plan
