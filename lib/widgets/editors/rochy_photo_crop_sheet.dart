import 'dart:io';
import '../editorial_image.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/bento_canvas_provider.dart';
import '../../theme/rochy_theme.dart';

/// Abre el recortador visual cómodo de fotos con proporciones, rotación 90°
/// y compresión automática para Firebase Storage (`<= 1280px` JPEG 78%).
Future<String?> showRochyPhotoCropSheet(
  BuildContext context,
  WidgetRef ref, {
  required String sourcePath,
  required RochyThemeData theme,
  bool startSquare = false,
}) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RochyPhotoCropBody(
      sourcePath: sourcePath,
      theme: theme,
      startSquare: startSquare,
    ),
  );
}

enum _CropAspectPreset {
  free('Libre', null),
  square('1:1', 1.0),
  landscape('4:3', 4 / 3),
  portrait('3:4', 3 / 4),
  polaroid('Polaroid', 4 / 5);

  const _CropAspectPreset(this.label, this.ratio);
  final String label;
  final double? ratio;
}

enum _DragHandle { none, move, topLeft, topRight, bottomLeft, bottomRight }

class _RochyPhotoCropBody extends ConsumerStatefulWidget {
  const _RochyPhotoCropBody({
    required this.sourcePath,
    required this.theme,
    this.startSquare = false,
  });

  final String sourcePath;
  final RochyThemeData theme;
  final bool startSquare;

  @override
  ConsumerState<_RochyPhotoCropBody> createState() =>
      _RochyPhotoCropBodyState();
}

class _RochyPhotoCropBodyState extends ConsumerState<_RochyPhotoCropBody> {
  double _rawAspectRatio = 1.0;
  int _originalBytes = 0;
  int _rotationQuarterTurns = 0;
  _CropAspectPreset _preset = _CropAspectPreset.free;
  Rect _cropRect = const Rect.fromLTWH(0.06, 0.06, 0.88, 0.88);
  _DragHandle _activeHandle = _DragHandle.none;
  Rect? _dragStartCrop;
  Offset? _dragStartLocal;
  bool _saving = false;
  bool _loadedMeta = false;

  @override
  void initState() {
    super.initState();
    _loadImageMeta();
  }

  Future<void> _loadImageMeta() async {
    try {
      final bytes = widget.sourcePath.startsWith('data:')
          ? Uri.parse(widget.sourcePath).data!.contentAsBytes().length
          : await File(widget.sourcePath).length();
      final ratio = await ref
          .read(mediaAndAuthServiceProvider)
          .detectImageAspectRatio(widget.sourcePath);
      if (!mounted) return;
      setState(() {
        _originalBytes = bytes;
        _rawAspectRatio = (ratio != null && ratio > 0.1) ? ratio : 1.0;
        _loadedMeta = true;
      });
      if (widget.startSquare && mounted) {
        _applyPreset(_CropAspectPreset.square);
      }
    } catch (_) {
      if (mounted) setState(() => _loadedMeta = true);
    }
  }

  double get _effectiveAspectRatio =>
      _rotationQuarterTurns.isOdd ? (1.0 / _rawAspectRatio) : _rawAspectRatio;

  void _applyPreset(_CropAspectPreset preset) {
    HapticFeedback.selectionClick();
    setState(() {
      _preset = preset;
      if (preset.ratio == null) {
        return;
      }
      // Convertir razón deseada (w/h en píxeles) a coordenadas normalizadas (0..1)
      final targetNormRatio = preset.ratio! / _effectiveAspectRatio;
      final cx = _cropRect.center.dx;
      final cy = _cropRect.center.dy;
      var w = _cropRect.width.clamp(0.25, 0.94);
      var h = w / targetNormRatio;
      if (h > 0.94) {
        h = 0.94;
        w = h * targetNormRatio;
      }
      if (w > 0.94) {
        w = 0.94;
        h = w / targetNormRatio;
      }
      final left = (cx - w / 2).clamp(0.0, 1.0 - w);
      final top = (cy - h / 2).clamp(0.0, 1.0 - h);
      _cropRect = Rect.fromLTWH(left, top, w, h);
    });
  }

  void _rotate90() {
    HapticFeedback.selectionClick();
    setState(() {
      _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
      _cropRect = const Rect.fromLTWH(0.06, 0.06, 0.88, 0.88);
      if (_preset.ratio != null) {
        final targetNormRatio = _preset.ratio! / _effectiveAspectRatio;
        var w = 0.86;
        var h = w / targetNormRatio;
        if (h > 0.88) {
          h = 0.88;
          w = (h * targetNormRatio).clamp(0.2, 0.92);
        }
        _cropRect = Rect.fromLTWH((1 - w) / 2, (1 - h) / 2, w, h);
      }
    });
  }

  _DragHandle _hitTestHandle(Offset local, Size box) {
    final pxRect = Rect.fromLTRB(
      _cropRect.left * box.width,
      _cropRect.top * box.height,
      _cropRect.right * box.width,
      _cropRect.bottom * box.height,
    );
    const cornerHit = 32.0;
    if ((local - pxRect.topLeft).distance <= cornerHit) {
      return _DragHandle.topLeft;
    }
    if ((local - pxRect.topRight).distance <= cornerHit) {
      return _DragHandle.topRight;
    }
    if ((local - pxRect.bottomLeft).distance <= cornerHit) {
      return _DragHandle.bottomLeft;
    }
    if ((local - pxRect.bottomRight).distance <= cornerHit) {
      return _DragHandle.bottomRight;
    }
    if (pxRect.inflate(10).contains(local)) {
      return _DragHandle.move;
    }
    return _DragHandle.none;
  }

  void _onPanUpdate(Offset local, Size box) {
    final startRect = _dragStartCrop;
    final startPt = _dragStartLocal;
    if (startRect == null ||
        startPt == null ||
        _activeHandle == _DragHandle.none) {
      return;
    }
    final dx = (local.dx - startPt.dx) / box.width;
    final dy = (local.dy - startPt.dy) / box.height;
    const minSpan = 0.16;

    setState(() {
      if (_activeHandle == _DragHandle.move) {
        final nl = (startRect.left + dx).clamp(0.0, 1.0 - startRect.width);
        final nt = (startRect.top + dy).clamp(0.0, 1.0 - startRect.height);
        _cropRect = Rect.fromLTWH(nl, nt, startRect.width, startRect.height);
        return;
      }

      var left = startRect.left;
      var top = startRect.top;
      var right = startRect.right;
      var bottom = startRect.bottom;

      switch (_activeHandle) {
        case _DragHandle.topLeft:
          left = (startRect.left + dx).clamp(0.0, right - minSpan);
          top = (startRect.top + dy).clamp(0.0, bottom - minSpan);
        case _DragHandle.topRight:
          right = (startRect.right + dx).clamp(left + minSpan, 1.0);
          top = (startRect.top + dy).clamp(0.0, bottom - minSpan);
        case _DragHandle.bottomLeft:
          left = (startRect.left + dx).clamp(0.0, right - minSpan);
          bottom = (startRect.bottom + dy).clamp(top + minSpan, 1.0);
        case _DragHandle.bottomRight:
          right = (startRect.right + dx).clamp(left + minSpan, 1.0);
          bottom = (startRect.bottom + dy).clamp(top + minSpan, 1.0);
        case _DragHandle.none:
        case _DragHandle.move:
          break;
      }

      if (_preset.ratio != null) {
        final normRatio = _preset.ratio! / _effectiveAspectRatio;
        var w = (right - left).clamp(minSpan, 1.0);
        var h = w / normRatio;
        if (h < minSpan) {
          h = minSpan;
          w = (h * normRatio).clamp(minSpan, 1.0);
        }
        if (_activeHandle == _DragHandle.topLeft ||
            _activeHandle == _DragHandle.bottomLeft) {
          left = (right - w).clamp(0.0, right - minSpan);
          w = right - left;
          h = w / normRatio;
        }
        if (_activeHandle == _DragHandle.topLeft ||
            _activeHandle == _DragHandle.topRight) {
          top = (bottom - h).clamp(0.0, bottom - minSpan);
          h = bottom - top;
          w = h * normRatio;
          if (_activeHandle == _DragHandle.topLeft) {
            left = (right - w).clamp(0.0, right - minSpan);
          } else {
            right = (left + w).clamp(left + minSpan, 1.0);
          }
        } else {
          bottom = (top + h).clamp(top + minSpan, 1.0);
          h = bottom - top;
          w = h * normRatio;
          if (_activeHandle == _DragHandle.bottomLeft) {
            left = (right - w).clamp(0.0, right - minSpan);
          } else {
            right = (left + w).clamp(left + minSpan, 1.0);
          }
        }
      }

      _cropRect = Rect.fromLTRB(
        left.clamp(0.0, 0.95),
        top.clamp(0.0, 0.95),
        right.clamp(left + 0.05, 1.0),
        bottom.clamp(top + 0.05, 1.0),
      );
    });
  }

  Future<void> _save({required bool fullImage}) async {
    if (_saving) return;
    HapticFeedback.lightImpact();
    setState(() => _saving = true);
    try {
      final rect =
          fullImage ? const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0) : _cropRect;
      final res = await ref
          .read(mediaAndAuthServiceProvider)
          .processCroppedAndCompressedImage(
            sourcePath: widget.sourcePath,
            cropLeft: rect.left,
            cropTop: rect.top,
            cropWidth: rect.width,
            cropHeight: rect.height,
            rotationDegrees: _rotationQuarterTurns * 90,
            maxDimension: 1280,
            quality: 78,
          );
      if (!mounted) return;
      Navigator.of(context).pop(res?.path ?? widget.sourcePath);
    } catch (_) {
      if (mounted) Navigator.of(context).pop(widget.sourcePath);
    }
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '';
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).ceil()} KB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final h = MediaQuery.sizeOf(context).height;

    return Container(
      height: h * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1411),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: <Widget>[
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 12, 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Recortar y comprimir foto',
                        style: RochyTypography.cardSerifTitle(
                          const Color(0xFFFAF7F2),
                          fontSize: 19,
                        ),
                      ),
                      Text(
                        _loadedMeta && _originalBytes > 0
                            ? 'Original: ${_formatSize(_originalBytes)} → Optimizada máx. 1280px'
                            : 'Ajusta el encuadre · Se comprime sola para la nube',
                        style: RochyTypography.metadata(
                          const Color(0xFFD7C8BC),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Center(
                child: AspectRatio(
                  aspectRatio: _effectiveAspectRatio.clamp(0.42, 2.2),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final box =
                          Size(constraints.maxWidth, constraints.maxHeight);
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (details) {
                          _activeHandle =
                              _hitTestHandle(details.localPosition, box);
                          _dragStartCrop = _cropRect;
                          _dragStartLocal = details.localPosition;
                        },
                        onPanUpdate: (details) =>
                            _onPanUpdate(details.localPosition, box),
                        onPanEnd: (_) => _activeHandle = _DragHandle.none,
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: RotatedBox(
                                quarterTurns: _rotationQuarterTurns,
                                child: EditorialImage(
                                  imageUrl: widget.sourcePath,
                                  fallbackScene:
                                      EditorialFallbackScene.handsSunday,
                                  fit: BoxFit.fill,
                                ),
                              ),
                            ),
                            CustomPaint(
                              painter: _CropOverlayPainter(
                                normRect: _cropRect,
                                accent: theme.terracotta,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: <Widget>[
                ActionChip(
                  avatar: const Icon(
                    Icons.rotate_90_degrees_cw_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  backgroundColor: Colors.white.withValues(alpha: 0.10),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  label: const Text(
                    'Rotar',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  onPressed: _saving ? null : _rotate90,
                ),
                const SizedBox(width: 8),
                ..._CropAspectPreset.values.map((preset) {
                  final selected = _preset == preset;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: selected,
                      selectedColor: theme.terracotta,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      side: BorderSide(
                        color: selected
                            ? theme.terracotta
                            : Colors.white.withValues(alpha: 0.18),
                      ),
                      label: Text(
                        preset.label,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      onSelected: _saving ? null : (_) => _applyPreset(preset),
                    ),
                  );
                }),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFAF7F2),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.28),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: _saving ? null : () => _save(fullImage: true),
                      child: const Text('Usar completa'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.terracotta,
                        foregroundColor: const Color(0xFFFAF7F2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: _saving ? null : () => _save(fullImage: false),
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.crop_rounded, size: 18),
                      label: Text(
                        _saving ? 'Comprimiendo…' : 'Recortar y guardar',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CropOverlayPainter extends CustomPainter {
  const _CropOverlayPainter({
    required this.normRect,
    required this.accent,
  });

  final Rect normRect;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    final crop = Rect.fromLTRB(
      normRect.left * size.width,
      normRect.top * size.height,
      normRect.right * size.width,
      normRect.bottom * size.height,
    );

    final dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.56);
    final maskPath = Path()
      ..addRect(full)
      ..addRect(crop)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(maskPath, dimPaint);

    // Borde exterior blanco
    canvas.drawRect(
      crop,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    // Rejilla de tercios
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.34)
      ..strokeWidth = 0.9;
    final dx = crop.width / 3;
    final dy = crop.height / 3;
    for (var i = 1; i <= 2; i++) {
      canvas.drawLine(
        Offset(crop.left + dx * i, crop.top),
        Offset(crop.left + dx * i, crop.bottom),
        gridPaint,
      );
      canvas.drawLine(
        Offset(crop.left, crop.top + dy * i),
        Offset(crop.right, crop.top + dy * i),
        gridPaint,
      );
    }

    // Esquinas gruesas de agarre
    final handlePaint = Paint()
      ..color = Color.lerp(accent, Colors.white, 0.25)!
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.2;
    final arm = math.min(22.0, math.min(crop.width, crop.height) * 0.35);

    void drawCorner(Offset corner, double sx, double sy) {
      final path = Path()
        ..moveTo(corner.dx + sx * arm, corner.dy)
        ..lineTo(corner.dx, corner.dy)
        ..lineTo(corner.dx, corner.dy + sy * arm);
      canvas.drawPath(path, handlePaint);
    }

    drawCorner(crop.topLeft, 1, 1);
    drawCorner(crop.topRight, -1, 1);
    drawCorner(crop.bottomLeft, 1, -1);
    drawCorner(crop.bottomRight, -1, -1);
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) {
    return oldDelegate.normRect != normRect || oldDelegate.accent != accent;
  }
}
