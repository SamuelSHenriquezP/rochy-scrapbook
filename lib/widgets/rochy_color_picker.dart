import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/rochy_theme.dart';

/// Selector visual interactivo con cuadro 2D (Saturación × Brillo), barra de matiz
/// y lectura HEX en tiempo real sin depender de paquetes externos.
class RochyColorPickerBox extends StatefulWidget {
  const RochyColorPickerBox({
    super.key,
    required this.color,
    required this.onColorChanged,
    required this.theme,
    this.squareHeight = 190.0,
  });

  final Color color;
  final ValueChanged<Color> onColorChanged;
  final RochyThemeData theme;
  final double squareHeight;

  @override
  State<RochyColorPickerBox> createState() => _RochyColorPickerBoxState();
}

class _RochyColorPickerBoxState extends State<RochyColorPickerBox> {
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.color);
  }

  @override
  void didUpdateWidget(covariant RochyColorPickerBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.color.toARGB32() != widget.color.toARGB32() &&
        widget.color.toARGB32() != _hsv.toColor().toARGB32()) {
      _hsv = HSVColor.fromColor(widget.color);
    }
  }

  void _updateSatVal(Offset local, Size size) {
    final s = (local.dx / size.width).clamp(0.0, 1.0);
    final v = (1.0 - (local.dy / size.height)).clamp(0.0, 1.0);
    final next = _hsv.withSaturation(s).withValue(v);
    setState(() => _hsv = next);
    widget.onColorChanged(next.toColor());
  }

  void _updateHue(Offset local, Size size) {
    final h = ((local.dx / size.width).clamp(0.0, 1.0) * 360.0)
        .clamp(0.0, 359.9);
    final next = _hsv.withHue(h);
    setState(() => _hsv = next);
    widget.onColorChanged(next.toColor());
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _hsv.toColor();
    final pureHue = HSVColor.fromAHSV(1.0, _hsv.hue, 1.0, 1.0).toColor();
    final hexLabel =
        '#${activeColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: widget.squareHeight,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                final cursorX = (_hsv.saturation * size.width - 12)
                    .clamp(0.0, size.width - 24);
                final cursorY = ((1.0 - _hsv.value) * size.height - 12)
                    .clamp(0.0, size.height - 24);

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) {
                    HapticFeedback.selectionClick();
                    _updateSatVal(d.localPosition, size);
                  },
                  onPanDown: (d) => _updateSatVal(d.localPosition, size),
                  onPanUpdate: (d) => _updateSatVal(d.localPosition, size),
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      ColoredBox(color: pureHue),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: <Color>[
                              Colors.white,
                              Color(0x00FFFFFF),
                            ],
                          ),
                        ),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              Color(0x00000000),
                              Colors.black,
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: cursorX,
                        top: cursorY,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: activeColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2.6,
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.45),
                                blurRadius: 6,
                                spreadRadius: 0.5,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 28,
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              final thumbX = ((_hsv.hue / 360.0) * size.width - 12)
                  .clamp(0.0, size.width - 24);

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) {
                  HapticFeedback.selectionClick();
                  _updateHue(d.localPosition, size);
                },
                onPanDown: (d) => _updateHue(d.localPosition, size),
                onPanUpdate: (d) => _updateHue(d.localPosition, size),
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: <Widget>[
                    Container(
                      height: 16,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: const LinearGradient(
                          colors: <Color>[
                            Color(0xFFFF0000),
                            Color(0xFFFFFF00),
                            Color(0xFF00FF00),
                            Color(0xFF00FFFF),
                            Color(0xFF0000FF),
                            Color(0xFFFF00FF),
                            Color(0xFFFF0000),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                    Positioned(
                      left: thumbX,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: pureHue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.6),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: activeColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.16),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              hexLabel,
              style: RochyTypography.metadata(
                widget.theme.inkSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
