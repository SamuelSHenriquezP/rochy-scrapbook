import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/bento_node.dart';
import '../theme/rochy_theme.dart';
import 'rochy_color_picker.dart';

/// Renderiza trazos normalizados ([0..1]) de un [SketchDoodlePayload] suavizados
/// mediante curvas cuadráticas de Bézier.
class SketchStrokesPainter extends CustomPainter {
  const SketchStrokesPainter({
    required this.strokes,
    this.activeStroke,
    this.baseStrokeScale = 1.0,
  });

  final List<SketchStroke> strokes;
  final SketchStroke? activeStroke;
  final double baseStrokeScale;

  @override
  void paint(Canvas canvas, Size size) {
    final all = <SketchStroke>[
      ...strokes,
      if (activeStroke != null) activeStroke!,
    ];

    for (final stroke in all) {
      if (stroke.points.isEmpty) continue;
      final paint = Paint()
        ..color = Color(stroke.colorHex)
        ..strokeWidth = stroke.strokeWidth * baseStrokeScale
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      if (stroke.points.length == 1) {
        final p = Offset(
          stroke.points.first[0] * size.width,
          stroke.points.first[1] * size.height,
        );
        canvas.drawCircle(
          p,
          paint.strokeWidth * 0.55,
          Paint()..color = paint.color,
        );
        continue;
      }

      final path = Path();
      final p0 = Offset(
        stroke.points[0][0] * size.width,
        stroke.points[0][1] * size.height,
      );
      path.moveTo(p0.dx, p0.dy);

      for (var i = 1; i < stroke.points.length - 1; i++) {
        final curr = Offset(
          stroke.points[i][0] * size.width,
          stroke.points[i][1] * size.height,
        );
        final next = Offset(
          stroke.points[i + 1][0] * size.width,
          stroke.points[i + 1][1] * size.height,
        );
        final mid = Offset((curr.dx + next.dx) / 2, (curr.dy + next.dy) / 2);
        path.quadraticBezierTo(curr.dx, curr.dy, mid.dx, mid.dy);
      }

      final last = stroke.points.last;
      path.lineTo(last[0] * size.width, last[1] * size.height);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SketchStrokesPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.activeStroke != activeStroke ||
        oldDelegate.baseStrokeScale != baseStrokeScale;
  }
}

/// Lienzo táctil de dibujo rápido con colores curados, selector libre 2D,
/// grosor de trazo, deshacer y limpiar.
class RochySketchPad extends StatefulWidget {
  const RochySketchPad({
    super.key,
    required this.strokes,
    required this.onChanged,
    required this.theme,
  });

  final List<SketchStroke> strokes;
  final ValueChanged<List<SketchStroke>> onChanged;
  final RochyThemeData theme;

  @override
  State<RochySketchPad> createState() => _RochySketchPadState();
}

class _RochySketchPadState extends State<RochySketchPad> {
  static const _quickPenHexes = <int>[
    0xFFA85338,
    0xFF2E221D,
    0xFF5B6E58,
    0xFF6B3D22,
    0xFFD4A373,
    0xFFFAF7F2,
  ];

  late Color _penColor;
  double _penWidth = 4.5;
  bool _showColorSquare = false;
  SketchStroke? _activeStroke;

  @override
  void initState() {
    super.initState();
    _penColor = widget.theme.brandAccent;
  }

  List<double> _normalize(Offset local, Size size) {
    final nx = (local.dx / (size.width <= 0 ? 1 : size.width)).clamp(0.0, 1.0);
    final ny =
        (local.dy / (size.height <= 0 ? 1 : size.height)).clamp(0.0, 1.0);
    return <double>[nx, ny];
  }

  void _startStroke(Offset local, Size size) {
    HapticFeedback.selectionClick();
    setState(() {
      _activeStroke = SketchStroke(
        colorHex: _penColor.toARGB32(),
        strokeWidth: _penWidth,
        points: <List<double>>[_normalize(local, size)],
      );
    });
  }

  void _appendStroke(Offset local, Size size) {
    final current = _activeStroke;
    if (current == null) return;
    final pt = _normalize(local, size);
    final last = current.points.last;
    if ((pt[0] - last[0]).abs() < 0.004 && (pt[1] - last[1]).abs() < 0.004) {
      return;
    }
    setState(() {
      _activeStroke = current.copyWith(
        points: <List<double>>[...current.points, pt],
      );
    });
  }

  void _finishStroke() {
    final current = _activeStroke;
    if (current == null) return;
    final next = <SketchStroke>[...widget.strokes, current];
    setState(() => _activeStroke = null);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'Dibuja aquí con el dedo',
                style: RochyTypography.metadata(
                  theme.inkSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: theme.inkPrimary,
                ),
                onPressed: widget.strokes.isEmpty
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        final copy = List<SketchStroke>.of(widget.strokes)
                          ..removeLast();
                        widget.onChanged(copy);
                      },
                icon: const Icon(Icons.undo_rounded, size: 16),
                label: const Text('Deshacer', style: TextStyle(fontSize: 12)),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: theme.terracotta,
                ),
                onPressed: widget.strokes.isEmpty
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        widget.onChanged(const <SketchStroke>[]);
                      },
                icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                label: const Text('Limpiar', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.ivorySurface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: theme.borderTint, width: 1.2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size =
                      Size(constraints.maxWidth, constraints.maxHeight);
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (d) => _startStroke(d.localPosition, size),
                    onPanUpdate: (d) => _appendStroke(d.localPosition, size),
                    onPanEnd: (_) => _finishStroke(),
                    onPanCancel: _finishStroke,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        CustomPaint(
                          painter: SketchStrokesPainter(
                            strokes: widget.strokes,
                            activeStroke: _activeStroke,
                          ),
                        ),
                        if (widget.strokes.isEmpty && _activeStroke == null)
                          Center(
                            child: Text(
                              'Garabatea un corazón, flor o firma…',
                              style: RochyTypography.metadata(
                                theme.inkSecondary.withValues(alpha: 0.55),
                                fontSize: 12.5,
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
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              for (final hex in _quickPenHexes)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _penColor = Color(hex));
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Color(hex),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _penColor.toARGB32() == hex
                              ? theme.brandAccent
                              : Colors.black.withValues(alpha: 0.18),
                          width: _penColor.toARGB32() == hex ? 2.4 : 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _showColorSquare = !_showColorSquare);
                },
                child: Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: _showColorSquare
                        ? theme.brandAccent.withValues(alpha: 0.14)
                        : theme.ivorySurface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _showColorSquare
                          ? theme.brandAccent
                          : theme.borderTint,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.palette_rounded,
                        size: 14,
                        color: theme.brandAccent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Color libre',
                        style: RochyTypography.metadata(
                          theme.inkPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <({String label, double width})>[
              (label: 'Fino', width: 2.8),
              (label: 'Medio', width: 5.0),
              (label: 'Grueso', width: 8.5),
            ].map((preset) {
              final selected = (_penWidth - preset.width).abs() < 0.2;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _penWidth = preset.width);
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? theme.brandAccent : theme.ivorySurface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected ? theme.brandAccent : theme.borderTint,
                      ),
                    ),
                    child: Text(
                      preset.label,
                      style: RochyTypography.metadata(
                        selected ? const Color(0xFFFAF7F2) : theme.inkPrimary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_showColorSquare) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.ivorySurface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: theme.borderTint),
              ),
              child: RochyColorPickerBox(
                color: _penColor,
                theme: theme,
                squareHeight: 155,
                onColorChanged: (c) => setState(() => _penColor = c),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
