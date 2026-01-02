import 'dart:math';

import 'package:flutter/material.dart';
import 'background_audio.dart';

///
/// Waveform bar widget
///
class BackgroundAudioWaveformBar extends StatelessWidget {
  ///
  /// Color
  ///
  final Color color;

  ///
  /// Bar style
  ///
  final BorderRadius borderRadius;

  final double value;
  final Random _random = Random();

  BackgroundAudioWaveformBar({
    super.key,
    required this.value,
    this.color = Colors.redAccent,
    this.borderRadius = const BorderRadius.only(
      topLeft: Radius.circular(4),
      topRight: Radius.circular(4),
    ),
  }) {
    // Ne pas modifier la graine aléatoire pour maintenir la cohérence
  }

  @override
  Widget build(BuildContext context) {
    // Ajouter un peu de variation à chaque barre
    final variation = _random.nextDouble() * 0.3 - 0.15; // -0.15 à +0.15
    final adjustedValue = (value + variation).clamp(0.0, 1.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      width: 6,
      height: 10 + (adjustedValue * 80),
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
      ),
    );
  }
}

///
/// Waveform widget
///
class BackgroundAudioLiveWaveform extends StatelessWidget {
  ///
  /// Color
  ///
  final Color color;

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
                color: color,
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
  final Color color;
  final BorderRadius borderRadius;

  const _VariedWaveformBar({
    required this.baseValue,
    required this.index,
    required this.color,
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

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      width: 6,
      height: _currentHeight,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: widget.borderRadius,
      ),
    );
  }
}
