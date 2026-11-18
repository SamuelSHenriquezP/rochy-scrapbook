import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pintor artesanal de forma de onda sonora con modulación armónica en vivo.
class WaveformPainter extends CustomPainter {
  const WaveformPainter({
    required this.samples,
    required this.progress,
    required this.isPlaying,
    required this.phase,
    required this.activeColor,
    required this.inactiveColor,
  });

  final List<double> samples;
  final double progress;
  final bool isPlaying;
  final double phase;
  final Color activeColor;
  final Color inactiveColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty || size.width <= 0 || size.height <= 0) return;

    final barCount = samples.length;
    final slotWidth = size.width / barCount;
    final barWidth = (slotWidth * 0.56).clamp(1.8, 3.6);
    final centerY = size.height / 2;

    final activePaint = Paint()
      ..color = activeColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    final inactivePaint = Paint()
      ..color = inactiveColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    for (var i = 0; i < barCount; i++) {
      final baseAmplitude = samples[i].clamp(0.14, 1.0);
      final harmonicBoost = isPlaying
          ? (0.14 * math.sin(phase + i * 0.65) +
              0.08 * math.cos(phase * 1.4 - i * 0.35))
          : 0.0;
      final normalizedHeight = (baseAmplitude + harmonicBoost).clamp(0.14, 1.0);
      final barHeight = normalizedHeight * (size.height * 0.88);
      final halfBar = barHeight / 2;
      final x = i * slotWidth + slotWidth / 2;

      final barProgress = (i + 0.5) / barCount;
      final isPlayed = barProgress <= progress && (isPlaying || progress > 0);

      canvas.drawLine(
        Offset(x, centerY - halfBar),
        Offset(x, centerY + halfBar),
        isPlayed ? activePaint : inactivePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.progress != progress ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.phase != phase ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}

/// Visualizador interactivo reutilizable para notas de voz y memoria sonora.
class InteractiveWaveformBar extends StatefulWidget {
  const InteractiveWaveformBar({
    super.key,
    required this.samples,
    required this.progress,
    required this.isPlaying,
    required this.activeColor,
    required this.inactiveColor,
    this.height = 30,
    this.onSeek,
  });

  final List<double> samples;
  final double progress;
  final bool isPlaying;
  final Color activeColor;
  final Color inactiveColor;
  final double height;
  final ValueChanged<double>? onSeek;

  @override
  State<InteractiveWaveformBar> createState() => _InteractiveWaveformBarState();
}

class _InteractiveWaveformBarState extends State<InteractiveWaveformBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (widget.isPlaying) {
      _waveController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant InteractiveWaveformBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_waveController.isAnimating) {
      _waveController.repeat();
    } else if (!widget.isPlaying && _waveController.isAnimating) {
      _waveController.stop();
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  void _handleScrub(Offset localPosition, double width) {
    if (widget.onSeek == null || width <= 0) return;
    final ratio = (localPosition.dx / width).clamp(0.0, 1.0);
    HapticFeedback.selectionClick();
    widget.onSeek!(ratio);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _handleScrub(details.localPosition, width),
          onHorizontalDragUpdate: (details) =>
              _handleScrub(details.localPosition, width),
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, _) {
                return CustomPaint(
                  painter: WaveformPainter(
                    samples: widget.samples,
                    progress: widget.progress,
                    isPlaying: widget.isPlaying,
                    phase: _waveController.value * math.pi * 2,
                    activeColor: widget.activeColor,
                    inactiveColor: widget.inactiveColor,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
