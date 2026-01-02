import 'dart:async';

import 'package:flutter/material.dart';
import 'background_audio.dart';

///
/// Waveform widget avec historique des données
///
class BackgroundAudioLiveHistoricWaveform extends StatefulWidget {
  ///
  /// Color de début du dégradé (optionnel, utilise color si null)
  ///
  final Color? colorStart;

  ///
  /// Color du milieu du dégradé
  ///
  final Color color;

  ///
  /// Color de fin du dégradé (optionnel, utilise color si null)
  ///
  final Color? colorEnd;

  ///
  /// Bar style
  ///
  final BorderRadius borderRadius;

  ///
  /// Count bar (nombre de barres affichées simultanément)
  ///
  final int countBar;

  ///
  /// Padding between bars
  ///
  final EdgeInsets padding;

  ///
  /// Maximum number of historical values to keep
  ///
  final int maxHistory;

  const BackgroundAudioLiveHistoricWaveform({
    super.key,
    this.colorStart,
    this.color = Colors.redAccent,
    this.colorEnd,
    this.borderRadius = const BorderRadius.only(
      topLeft: Radius.circular(4),
      topRight: Radius.circular(4),
    ),
    this.countBar = 30,
    this.padding = const EdgeInsets.symmetric(horizontal: 2),
    this.maxHistory = 100,
  });

  @override
  State<BackgroundAudioLiveHistoricWaveform> createState() =>
      _BackgroundAudioLiveHistoricWaveformState();
}

class _BackgroundAudioLiveHistoricWaveformState
    extends State<BackgroundAudioLiveHistoricWaveform> {
  final List<double> _historicalValues = [];
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
        // Ajouter la nouvelle valeur à l'historique
        _historicalValues.add(value);

        // Limiter la taille de l'historique
        if (_historicalValues.length > widget.maxHistory) {
          _historicalValues.removeAt(0);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: BackgroundAudioService.waveformStream,
      builder: (context, snapshot) {
        // Obtenir les dernières valeurs pour l'affichage
        final recentValues = _historicalValues.isEmpty
            ? List<double>.filled(widget.countBar, 0.0)
            : _historicalValues.length >= widget.countBar
                ? _historicalValues
                    .sublist(_historicalValues.length - widget.countBar)
                : _historicalValues +
                    List<double>.filled(
                        widget.countBar - _historicalValues.length, 0.0);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.countBar,
            (index) => Padding(
              padding: widget.padding,
              child: _HistoricWaveformBar(
                value: recentValues[index],
                index: index,
                totalBars: widget.countBar,
                colorStart: widget.colorStart,
                color: widget.color,
                colorEnd: widget.colorEnd,
                borderRadius: widget.borderRadius,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HistoricWaveformBar extends StatelessWidget {
  final double value;
  final int index;
  final int totalBars;
  final Color? colorStart;
  final Color color;
  final Color? colorEnd;
  final BorderRadius borderRadius;

  const _HistoricWaveformBar({
    required this.value,
    required this.index,
    required this.totalBars,
    required this.colorStart,
    required this.color,
    required this.colorEnd,
    required this.borderRadius,
  });

  /// Fonction utilitaire pour interpoler entre deux couleurs
  Color _interpolateColor(Color start, Color end, double factor) {
    return Color.lerp(start, end, factor) ?? start;
  }

  /// Obtenir les couleurs effectives (avec fallback vers color)
  Color _getEffectiveColorStart() => colorStart ?? color;
  Color _getEffectiveColorEnd() => colorEnd ?? color;

  /// Obtenir la couleur de la barre selon sa position dans le dégradé
  Color _getBarColor() {
    if (totalBars <= 1) return color;

    final factor =
        index / (totalBars - 1); // 0.0 pour la première, 1.0 pour la dernière

    final effectiveColorStart = _getEffectiveColorStart();
    final effectiveColorEnd = _getEffectiveColorEnd();

    if (factor <= 0.5) {
      // Première moitié : colorStart → color
      final adjustedFactor = factor * 2; // 0.0 à 1.0
      return _interpolateColor(effectiveColorStart, color, adjustedFactor);
    } else {
      // Seconde moitié : color → colorEnd
      final adjustedFactor = (factor - 0.5) * 2; // 0.0 à 1.0
      return _interpolateColor(color, effectiveColorEnd, adjustedFactor);
    }
  }

  @override
  Widget build(BuildContext context) {
    final barColor = _getBarColor();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 4,
      height: 10 + (value * 80),
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: borderRadius,
      ),
    );
  }
}
