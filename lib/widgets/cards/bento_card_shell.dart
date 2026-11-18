import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/bento_node.dart';
import '../../theme/rochy_theme.dart';

/// Estado visual de un nodo dentro del grafo relacional tras pulsación prolongada.
enum BentoRelationHighlight {
  normal,
  selected,
  linked,
  dimmed,
}

/// Contenedor táctil optimizado (con [RepaintBoundary]) para las tarjetas Bento.
///
/// Soporta estilos de diseño ([BentoCardDesign]), degradado orgánico, radio
/// personalizable, borde fino translúcido y foco del grafo relacional.
class BentoCardShell extends StatefulWidget {
  const BentoCardShell({
    super.key,
    required this.theme,
    required this.backgroundColor,
    required this.child,
    this.node,
    this.relationHighlight = BentoRelationHighlight.normal,
    this.showPaperGrain = true,
    this.borderRadius,
    this.padding = EdgeInsets.zero,
    this.onTap,
    this.onLongPress,
    this.enablePressScale = true,
    this.clipBehavior = Clip.antiAlias,
  });

  final RochyThemeData theme;
  final Color backgroundColor;
  final Widget child;
  final BentoNode? node;
  final BentoRelationHighlight relationHighlight;
  final bool showPaperGrain;
  final double? borderRadius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enablePressScale;
  final Clip clipBehavior;

  @override
  State<BentoCardShell> createState() => _BentoCardShellState();
}

class _BentoCardShellState extends State<BentoCardShell> {
  bool _isPressed = false;

  void _setPressed(bool pressed) {
    if (!widget.enablePressScale || _isPressed == pressed) return;
    setState(() => _isPressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final effectiveRadius =
        widget.borderRadius ?? node?.borderRadius ?? 24.0;
    final design = node?.cardDesign ?? BentoCardDesign.editorial;
    final useGradient = node?.useGradient ?? false;

    final targetOpacity = switch (widget.relationHighlight) {
      BentoRelationHighlight.dimmed => 0.35,
      _ => 1.0,
    };

    final relationScale = switch (widget.relationHighlight) {
      BentoRelationHighlight.selected => 1.022,
      BentoRelationHighlight.linked => 1.01,
      BentoRelationHighlight.dimmed => 0.985,
      BentoRelationHighlight.normal => 1.0,
    };

    final pressScale = _isPressed ? 0.968 : 1.0;
    final radius = BorderRadius.circular(effectiveRadius);

    final baseBg = design == BentoCardDesign.glassTint
        ? widget.backgroundColor.withValues(alpha: 0.72)
        : widget.backgroundColor;

    final Gradient? bgGradient = useGradient
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color.lerp(baseBg, Colors.white, 0.14)!,
              baseBg,
              Color.lerp(baseBg, const Color(0xFF231610), 0.12)!,
            ],
          )
        : null;

    final shadows = <BoxShadow>[
      if (design != BentoCardDesign.outlined)
        BoxShadow(
          color: const Color(0xFF2D1E16).withValues(alpha: 0.08),
          blurRadius: 16,
          spreadRadius: -3,
          offset: const Offset(0, 8),
        ),
      if (design == BentoCardDesign.softGlow)
        BoxShadow(
          color: widget.backgroundColor.withValues(alpha: 0.34),
          blurRadius: 22,
          spreadRadius: 1,
          offset: const Offset(0, 6),
        ),
      if (widget.relationHighlight == BentoRelationHighlight.selected ||
          widget.relationHighlight == BentoRelationHighlight.linked)
        BoxShadow(
          color: widget.theme.haloColor.withValues(
            alpha: widget.relationHighlight == BentoRelationHighlight.selected
                ? 0.42
                : 0.30,
          ),
          blurRadius: 20,
          spreadRadius: 2,
          offset: const Offset(0, 4),
        ),
    ];

    final borderColor = switch (widget.relationHighlight) {
      BentoRelationHighlight.selected =>
        widget.theme.haloColor.withValues(alpha: 0.85),
      BentoRelationHighlight.linked =>
        widget.theme.haloColor.withValues(alpha: 0.55),
      _ => design == BentoCardDesign.outlined
          ? widget.theme.inkSecondary.withValues(alpha: 0.32)
          : design == BentoCardDesign.glassTint
              ? Colors.white.withValues(alpha: 0.55)
              : widget.theme.borderTint,
    };

    final borderWidth = switch (widget.relationHighlight) {
      BentoRelationHighlight.selected => 1.8,
      BentoRelationHighlight.linked => 1.3,
      _ => design == BentoCardDesign.outlined ? 1.5 : 1.0,
    };

    return RepaintBoundary(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        opacity: targetOpacity,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          scale: relationScale * pressScale,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _setPressed(true),
            onTapUp: (_) => _setPressed(false),
            onTapCancel: () => _setPressed(false),
            onTap: widget.onTap,
            onLongPress: widget.onLongPress == null
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    widget.onLongPress!();
                  },
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: bgGradient == null ? baseBg : null,
                gradient: bgGradient,
                borderRadius: radius,
                border: Border.all(
                  color: borderColor,
                  width: borderWidth,
                ),
                boxShadow: shadows,
              ),
              child: ClipRRect(
                borderRadius: radius,
                clipBehavior: widget.clipBehavior,
                child: Stack(
                  fit: StackFit.passthrough,
                  children: <Widget>[
                    if (design == BentoCardDesign.notebookRuled)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _NotebookRuledPainter(
                              lineColor: widget.theme.inkSecondary
                                  .withValues(alpha: 0.12),
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: widget.padding,
                      child: widget.child,
                    ),
                    if (widget.showPaperGrain &&
                        design != BentoCardDesign.glassTint)
                      const Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _PaperGrainPainter(),
                          ),
                        ),
                      ),
                    if (node?.isFavorite == true)
                      Positioned(
                        top: 9,
                        left: 9,
                        child: IgnorePointer(
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: widget.theme.terracotta.withValues(
                                alpha: 0.92,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.14),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.favorite_rounded,
                              size: 12,
                              color: Color(0xFFFAF7F2),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotebookRuledPainter extends CustomPainter {
  const _NotebookRuledPainter({required this.lineColor});

  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.9;

    for (var y = 26.0; y < size.height - 12; y += 22.0) {
      canvas.drawLine(Offset(14, y), Offset(size.width - 14, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NotebookRuledPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor;
  }
}

class _PaperGrainPainter extends CustomPainter {
  const _PaperGrainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final speckPaint = Paint()
      ..color = const Color(0xFF382923).withValues(alpha: 0.03)
      ..style = PaintingStyle.fill;

    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;

    const count = 24;
    for (var i = 0; i < count; i++) {
      final rx = _pseudoRandom(i * 17 + 3);
      final ry = _pseudoRandom(i * 31 + 7);
      final offset = Offset(rx * size.width, ry * size.height);
      canvas.drawCircle(
        offset,
        0.9,
        i.isEven ? speckPaint : highlightPaint,
      );
    }
  }

  double _pseudoRandom(int seed) {
    final x = math.sin(seed * 12.9898) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  bool shouldRepaint(covariant _PaperGrainPainter oldDelegate) => false;
}
