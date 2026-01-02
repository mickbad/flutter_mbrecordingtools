import 'dart:math';

import 'package:flutter/material.dart';
import 'background_audio.dart';

///
/// Waveform bar widget avec dégradé à 3 couleurs
/// Séquence de dégradé: colorStart (début) → color (milieu) → colorEnd (fin)
///
class BackgroundAudioWaveformBar extends StatelessWidget {
  ///
  /// Color du milieu
  ///
  final Color color;

  ///
  /// Color de début du dégradé
  ///
  final Color colorStart;

  ///
  /// Color de fin du dégradé
  ///
  final Color colorEnd;

  ///
  /// Bar style
  ///
  final BorderRadius borderRadius;

  final double value;
  final int index;
  final int totalBars;
  final Random _random = Random();

  BackgroundAudioWaveformBar({
    super.key,
    required this.value,
    this.index = 0,
    this.totalBars = 1,
    this.color = Colors.redAccent,
    this.colorStart = Colors.blueAccent,
    this.colorEnd = Colors.greenAccent,
    this.borderRadius = const BorderRadius.only(
      topLeft: Radius.circular(4),
      topRight: Radius.circular(4),
    ),
  }) {
    // Ne pas modifier la graine aléatoire pour maintenir la cohérence
  }

  /// Fonction utilitaire pour interpoler entre deux couleurs
  Color _interpolateColor(Color start, Color end, double factor) {
    return Color.lerp(start, end, factor) ?? start;
  }

  /// Obtenir la couleur de la barre selon sa position dans le dégradé
  Color _getBarColor() {
    if (totalBars <= 1) return color;

    final factor =
        index / (totalBars - 1); // 0.0 pour la première, 1.0 pour la dernière

    if (factor <= 0.5) {
      // Première moitié : colorStart → color
      final adjustedFactor = factor * 2; // 0.0 à 1.0
      return _interpolateColor(colorStart, color, adjustedFactor);
    } else {
      // Seconde moitié : color → colorEnd
      final adjustedFactor = (factor - 0.5) * 2; // 0.0 à 1.0
      return _interpolateColor(color, colorEnd, adjustedFactor);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ajouter un peu de variation à chaque barre
    final variation = _random.nextDouble() * 0.3 - 0.15; // -0.15 à +0.15
    final adjustedValue = (value + variation).clamp(0.0, 1.0);

    final barColor = _getBarColor();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      width: 6,
      height: 10 + (adjustedValue * 80),
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: borderRadius,
      ),
    );
  }
}

///
/// Waveform widget avec dégradé à 3 couleurs
/// Séquence de dégradé: colorStart (début) → color (milieu) → colorEnd (fin)
///
class BackgroundAudioLiveWaveform extends StatelessWidget {
  ///
  /// Color du milieu
  ///
  final Color color;

  ///
  /// Color de début du dégradé (optionnel, utilise color si null)
  ///
  final Color? colorStart;

  ///
  /// Color de fin du dégradé (optionnel, utilise color si null)
  ///
  final Color? colorEnd;

  ///
  /// Bar style
  ///
  final BorderRadius borderRadius;

  ///
  /// Count bar
  ///
  final int countBar;

  ///
  /// Padding between bars
  ///
  final EdgeInsets padding;

  const BackgroundAudioLiveWaveform({
    super.key,
    this.color = Colors.redAccent,
    this.colorStart,
    this.colorEnd,
    this.borderRadius = const BorderRadius.only(
      topLeft: Radius.circular(4),
      topRight: Radius.circular(4),
    ),
    this.countBar = 20,
    this.padding = const EdgeInsets.symmetric(horizontal: 2),
  });

  @override
  Widget build(BuildContext context) {
    // count min
    int countRealBar = countBar;
    if (countRealBar < 1) {
      countRealBar = 1;
    }

    return StreamBuilder<double>(
      stream: BackgroundAudioService.waveformStream,
      builder: (context, snapshot) {
        final value = snapshot.data ?? 0;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            countRealBar,
            (index) => Padding(
              padding: padding,
              child: _VariedWaveformBar(
                baseValue: value,
                index: index,
                totalBars: countRealBar,
                color: color,
                colorStart: colorStart,
                colorEnd: colorEnd,
                borderRadius: borderRadius,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VariedWaveformBar extends StatefulWidget {
  final double baseValue;
  final int index;
  final int totalBars;
  final Color color;
  final Color? colorStart;
  final Color? colorEnd;
  final BorderRadius borderRadius;

  const _VariedWaveformBar({
    required this.baseValue,
    required this.index,
    required this.totalBars,
    required this.color,
    required this.colorStart,
    required this.colorEnd,
    required this.borderRadius,
  });

  @override
  State<_VariedWaveformBar> createState() => _VariedWaveformBarState();
}

class _VariedWaveformBarState extends State<_VariedWaveformBar> {
  late double _currentHeight;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _currentHeight = 10;
  }

  @override
  void didUpdateWidget(_VariedWaveformBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.baseValue != widget.baseValue) {
      // Calculer une variation basée sur l'index pour que les barres bougent différemment
      final variation = ((_random.nextDouble() * 0.7) - 0.2) * widget.baseValue;
      _currentHeight =
          6 + ((widget.baseValue + variation).clamp(0.0, 1.0) * 80);
    }
  }

  /// Fonction utilitaire pour interpoler entre deux couleurs
  Color _interpolateColor(Color start, Color end, double factor) {
    return Color.lerp(start, end, factor) ?? start;
  }

  /// Obtenir les couleurs effectives (avec fallback vers color)
  Color _getEffectiveColorStart() => widget.colorStart ?? widget.color;
  Color _getEffectiveColorEnd() => widget.colorEnd ?? widget.color;

  /// Obtenir la couleur de la barre selon sa position dans le dégradé
  Color _getBarColor() {
    if (widget.totalBars <= 1) return widget.color;

    final factor = widget.index /
        (widget.totalBars - 1); // 0.0 pour la première, 1.0 pour la dernière

    final effectiveColorStart = _getEffectiveColorStart();
    final effectiveColorEnd = _getEffectiveColorEnd();

    if (factor <= 0.5) {
      // Première moitié : colorStart → color
      final adjustedFactor = factor * 2; // 0.0 à 1.0
      return _interpolateColor(
          effectiveColorStart, widget.color, adjustedFactor);
    } else {
      // Seconde moitié : color → colorEnd
      final adjustedFactor = (factor - 0.5) * 2; // 0.0 à 1.0
      return _interpolateColor(widget.color, effectiveColorEnd, adjustedFactor);
    }
  }

  @override
  Widget build(BuildContext context) {
    final barColor = _getBarColor();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      width: 6,
      height: _currentHeight,
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: widget.borderRadius,
      ),
    );
  }
}
