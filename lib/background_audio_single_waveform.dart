import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'background_audio.dart';

/// Enum pour l'orientation de la jauge
enum WaveformOrientation {
  vertical,
  horizontal,
}

/// Jauge simple avec dégradé de couleur basée sur l'amplitude audio
class BackgroundAudioLiveSingleWaveform extends StatefulWidget {
  /// Couleur de début du dégradé (optionnel, utilise color si null)
  final Color? colorStart;

  /// Couleur du milieu (couleur de base)
  final Color color;

  /// Couleur de fin du dégradé (optionnel, utilise color si null)
  final Color? colorEnd;

  /// Couleur du cadre
  final Color borderColor;

  /// Border radius du cadre
  final BorderRadius borderRadius;

  /// Orientation de la jauge
  final WaveformOrientation orientation;

  /// Padding interne du cadre
  final EdgeInsets padding;

  /// Durée d'animation en millisecondes
  final int animationDurationMs;

  const BackgroundAudioLiveSingleWaveform({
    super.key,
    this.colorStart,
    this.color = Colors.redAccent,
    this.colorEnd,
    this.borderColor = Colors.grey,
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
    this.orientation = WaveformOrientation.vertical,
    this.padding = const EdgeInsets.all(0.0),
    this.animationDurationMs = 150,
  });

  @override
  State<BackgroundAudioLiveSingleWaveform> createState() =>
      _BackgroundAudioLiveSingleWaveformState();
}

class _BackgroundAudioLiveSingleWaveformState
    extends State<BackgroundAudioLiveSingleWaveform> {
  double _currentAmplitude = 0.0;
  late StreamSubscription<double>? _waveformSub;

  @override
  void initState() {
    super.initState();
    _startListeningToWaveform();
  }

  @override
  void dispose() {
    _waveformSub?.cancel();
    super.dispose();
  }

  void _startListeningToWaveform() {
    _waveformSub = BackgroundAudioService.waveformStream.listen((value) {
      setState(() {
        _currentAmplitude = value;
      });
    });
  }

  /// Fonction utilitaire pour interpoler entre deux couleurs
  Color _interpolateColor(Color start, Color end, double factor) {
    return Color.lerp(start, end, factor) ?? start;
  }

  /// Obtenir les couleurs effectives (avec fallback vers color)
  Color _getEffectiveColorStart() => widget.colorStart ?? widget.color;
  Color _getEffectiveColorEnd() => widget.colorEnd ?? widget.color;

  /// Obtenir la couleur selon l'amplitude
  Color _getAmplitudeColor(double amplitude) {
    final effectiveColorStart = _getEffectiveColorStart();
    final effectiveColorEnd = _getEffectiveColorEnd();

    if (amplitude <= 0.5) {
      // Première moitié : colorStart → color
      final adjustedFactor = amplitude * 2; // 0.0 à 1.0
      return _interpolateColor(
          effectiveColorStart, widget.color, adjustedFactor);
    } else {
      // Seconde moitié : color → colorEnd
      final adjustedFactor = (amplitude - 0.5) * 2; // 0.0 à 1.0
      return _interpolateColor(widget.color, effectiveColorEnd, adjustedFactor);
    }
  }

  /// Construire la jauge horizontale
  Widget _buildHorizontalGauge() {
    final amplitudeColor = _getAmplitudeColor(_currentAmplitude);
    final filledWidth = _currentAmplitude.clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final filledWidthPx = availableWidth * filledWidth;

        return Container(
          height: 20, // Hauteur fixe pour la jauge horizontale
          padding: widget.padding,
          decoration: BoxDecoration(
            border: Border.all(color: widget.borderColor),
            borderRadius: widget.borderRadius,
          ),
          child: Stack(
            children: [
              // Fond de la jauge (transparent pour éviter la zone grise)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: widget.borderRadius,
                  ),
                ),
              ),
              // Jauge de remplissage
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: AnimatedContainer(
                  duration: Duration(milliseconds: widget.animationDurationMs),
                  width: filledWidthPx,
                  decoration: BoxDecoration(
                    color: amplitudeColor,
                    borderRadius: widget.borderRadius,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Construire la jauge verticale
  Widget _buildVerticalGauge() {
    final amplitudeColor = _getAmplitudeColor(_currentAmplitude);
    final filledHeight = _currentAmplitude.clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final filledHeightPx = availableHeight * filledHeight;

        return Container(
          width: 30, // Largeur fixe pour la jauge verticale
          padding: widget.padding,
          decoration: BoxDecoration(
            border: Border.all(color: widget.borderColor),
            borderRadius: widget.borderRadius,
          ),
          child: Stack(
            children: [
              // Fond de la jauge (transparent pour éviter la zone grise)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: widget.borderRadius,
                  ),
                ),
              ),
              // Jauge de remplissage
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedContainer(
                  duration: Duration(milliseconds: widget.animationDurationMs),
                  height: filledHeightPx,
                  decoration: BoxDecoration(
                    color: amplitudeColor,
                    borderRadius: widget.borderRadius,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.orientation == WaveformOrientation.horizontal
        ? _buildHorizontalGauge()
        : _buildVerticalGauge();
  }
}
