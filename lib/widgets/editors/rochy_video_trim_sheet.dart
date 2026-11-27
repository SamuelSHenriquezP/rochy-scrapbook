import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../providers/bento_canvas_provider.dart';
import '../../theme/rochy_theme.dart';

typedef TrimmedVideoResult = ({
  String videoPath,
  String thumbnailPath,
  int durationSeconds,
  int sizeBytes,
});

/// Recortador visual cómodo de videos (máximo 30.0 s) con tira de miniaturas,
/// segundos exactos (`00:12.4`), previsualización del instante al arrastrar
/// y ajuste fino de inicio/fin.
Future<TrimmedVideoResult?> showRochyVideoTrimSheet(
  BuildContext context,
  WidgetRef ref, {
  required String sourcePath,
  required RochyThemeData theme,
}) async {
  if (kIsWeb) {
    final info = await ref
        .read(mediaAndAuthServiceProvider)
        .inspectVideoForTrimmer(sourcePath);
    if (!context.mounted) return null;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
      content: Text(
          'Se adjuntará el video completo. El recorte está disponible en la app del teléfono.'),
    ));
    return (
      videoPath: sourcePath,
      thumbnailPath: '',
      durationSeconds: (info.durationMs / 1000).ceil(),
      sizeBytes: Uri.parse(sourcePath).data?.contentAsBytes().length ?? 0
    );
  }
  return showModalBottomSheet<TrimmedVideoResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RochyVideoTrimBody(
      sourcePath: sourcePath,
      theme: theme,
    ),
  );
}

enum _TrimDragMode { none, start, end, window }

class _RochyVideoTrimBody extends ConsumerStatefulWidget {
  const _RochyVideoTrimBody({
    required this.sourcePath,
    required this.theme,
  });

  final String sourcePath;
  final RochyThemeData theme;

  @override
  ConsumerState<_RochyVideoTrimBody> createState() =>
      _RochyVideoTrimBodyState();
}

class _RochyVideoTrimBodyState extends ConsumerState<_RochyVideoTrimBody> {
  static const int _maxClipMs = 30000;
  static const int _minClipMs = 1000;

  VideoPlayerController? _controller;
  bool _playerReady = false;
  int _totalMs = 10000;
  int _startMs = 0;
  int _endMs = 10000;
  int _playheadMs = 0;
  List<String> _thumbs = const <String>[];
  double _aspectRatio = 16 / 9;
  int _originalBytes = 0;
  bool _saving = false;

  _TrimDragMode _dragMode = _TrimDragMode.none;
  int _dragInitStartMs = 0;
  int _dragInitEndMs = 0;
  double _dragInitDx = 0;
  DateTime _lastSeekAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final file = File(widget.sourcePath);
    try {
      _originalBytes = await file.length();
    } catch (_) {}

    final ctrl = VideoPlayerController.file(file);
    _controller = ctrl;
    try {
      await ctrl.initialize();
      ctrl.addListener(_onPlayerTick);
      final durMs = math.max(1000, ctrl.value.duration.inMilliseconds);
      final ratio =
          ctrl.value.aspectRatio > 0.1 ? ctrl.value.aspectRatio : 16 / 9;
      if (mounted) {
        setState(() {
          _totalMs = durMs;
          _startMs = 0;
          _endMs = math.min(durMs, _maxClipMs);
          _playheadMs = 0;
          _aspectRatio = ratio;
          _playerReady = true;
        });
      }
      await ctrl.play();
    } catch (_) {}

    final meta = await ref
        .read(mediaAndAuthServiceProvider)
        .inspectVideoForTrimmer(widget.sourcePath, frameCount: 8);
    if (!mounted) return;
    setState(() {
      if (meta.durationMs > 500) {
        _totalMs = meta.durationMs;
        if (_endMs > _totalMs) _endMs = math.min(_totalMs, _maxClipMs);
      }
      _thumbs = meta.thumbnails;
    });
  }

  void _onPlayerTick() {
    final ctrl = _controller;
    if (ctrl == null || !mounted || _dragMode != _TrimDragMode.none) return;
    final posMs = ctrl.value.position.inMilliseconds;
    if (posMs >= _endMs && ctrl.value.isPlaying) {
      ctrl.seekTo(Duration(milliseconds: _startMs));
    }
    if ((posMs - _playheadMs).abs() >= 75) {
      setState(() => _playheadMs = posMs.clamp(_startMs, _endMs));
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onPlayerTick);
    _controller?.dispose();
    super.dispose();
  }

  String _fmt(int ms) {
    final safe = math.max(0, ms);
    final totalSec = safe ~/ 1000;
    final tenths = (safe % 1000) ~/ 100;
    final mins = totalSec ~/ 60;
    final secs = totalSec % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}.$tenths';
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '';
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).ceil()} KB';
  }

  void _seekLive(int targetMs, {bool pauseFirst = true}) {
    final ctrl = _controller;
    if (ctrl == null || !_playerReady) return;
    if (pauseFirst && ctrl.value.isPlaying) {
      ctrl.pause();
    }
    final now = DateTime.now();
    if (now.difference(_lastSeekAt).inMilliseconds >= 60) {
      _lastSeekAt = now;
      ctrl.seekTo(Duration(milliseconds: targetMs.clamp(0, _totalMs)));
    }
  }

  void _nudgeStart(int deltaMs) {
    HapticFeedback.selectionClick();
    setState(() {
      var nextStart = (_startMs + deltaMs).clamp(0, _totalMs - _minClipMs);
      var nextEnd = _endMs;
      if (nextEnd - nextStart < _minClipMs) {
        nextEnd = (nextStart + _minClipMs).clamp(_minClipMs, _totalMs);
        nextStart = math.max(0, nextEnd - _minClipMs);
      } else if (nextEnd - nextStart > _maxClipMs) {
        nextEnd = (nextStart + _maxClipMs).clamp(_minClipMs, _totalMs);
      }
      _startMs = nextStart;
      _endMs = nextEnd;
      _playheadMs = _startMs;
    });
    _seekLive(_startMs);
  }

  void _nudgeEnd(int deltaMs) {
    HapticFeedback.selectionClick();
    setState(() {
      var nextEnd = (_endMs + deltaMs).clamp(_minClipMs, _totalMs);
      var nextStart = _startMs;
      if (nextEnd - nextStart < _minClipMs) {
        nextStart = (nextEnd - _minClipMs).clamp(0, _totalMs - _minClipMs);
        nextEnd = math.min(_totalMs, nextStart + _minClipMs);
      } else if (nextEnd - nextStart > _maxClipMs) {
        nextStart = math.max(0, nextEnd - _maxClipMs);
      }
      _startMs = nextStart;
      _endMs = nextEnd;
      _playheadMs = _endMs;
    });
    _seekLive(_endMs);
  }

  Future<void> _togglePlay() async {
    final ctrl = _controller;
    if (ctrl == null || !_playerReady) return;
    HapticFeedback.selectionClick();
    if (ctrl.value.isPlaying) {
      await ctrl.pause();
    } else {
      final pos = ctrl.value.position.inMilliseconds;
      if (pos < _startMs || pos >= _endMs) {
        await ctrl.seekTo(Duration(milliseconds: _startMs));
      }
      await ctrl.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _confirmTrim() async {
    if (_saving) return;
    HapticFeedback.lightImpact();
    _controller?.pause();
    setState(() => _saving = true);

    final result =
        await ref.read(mediaAndAuthServiceProvider).trimAndOptimizeVideoFile(
              sourcePath: widget.sourcePath,
              startMs: _startMs,
              endMs: _endMs,
            );

    if (!mounted) return;
    if (result != null) {
      Navigator.of(context).pop(result);
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('No se pudo recortar el video. Intenta otro rango.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final h = MediaQuery.sizeOf(context).height;
    final selectedMs = math.max(0, _endMs - _startMs);
    final selectedSecsLabel = '${(selectedMs / 1000).toStringAsFixed(1)} s';

    return Container(
      height: h * 0.90,
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
            padding: const EdgeInsets.fromLTRB(18, 12, 12, 6),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Recortar video (máx. 30 s)',
                        style: RochyTypography.cardSerifTitle(
                          const Color(0xFFFAF7F2),
                          fontSize: 19,
                        ),
                      ),
                      Text(
                        'Duración total: ${_fmt(_totalMs)}${_originalBytes > 0 ? ' · ${_formatSize(_originalBytes)}' : ''}',
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

          // Visor del video en vivo para ver el momento exacto
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Center(
                child: AspectRatio(
                  aspectRatio: _aspectRatio.clamp(0.55, 1.9),
                  child: GestureDetector(
                    onTap: _togglePlay,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          if (_playerReady && _controller != null)
                            VideoPlayer(_controller!)
                          else
                            const ColoredBox(
                              color: Color(0xFF281F1A),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFFFAF7F2),
                                ),
                              ),
                            ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.62),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Text(
                                _fmt(_playheadMs),
                                style: const TextStyle(
                                  color: Color(0xFFFAF7F2),
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ),
                          if (!_playerReady ||
                              !(_controller?.value.isPlaying ?? false))
                            Center(
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.48),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.55),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 30,
                                  color: Colors.white,
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
          ),

          // Marcadores de segundos + ajuste fino
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _TimeAdjustBox(
                    label: 'Inicio',
                    timeText: _fmt(_startMs),
                    onMinus: () => _nudgeStart(-500),
                    onPlus: () => _nudgeStart(500),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: theme.terracotta.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.terracotta.withValues(alpha: 0.65),
                    ),
                  ),
                  child: Column(
                    children: <Widget>[
                      Text(
                        selectedSecsLabel,
                        style: const TextStyle(
                          color: Color(0xFFFAF7F2),
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const Text(
                        'máx. 30 s',
                        style: TextStyle(
                          color: Color(0xFFE7C7B4),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TimeAdjustBox(
                    label: 'Fin',
                    timeText: _fmt(_endMs),
                    onMinus: () => _nudgeEnd(-500),
                    onPlus: () => _nudgeEnd(500),
                  ),
                ),
              ],
            ),
          ),

          // Tira de película arrastrable
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final trackW = math.max(120.0, constraints.maxWidth);
                final startRatio =
                    _totalMs > 0 ? (_startMs / _totalMs).clamp(0.0, 1.0) : 0.0;
                final endRatio =
                    _totalMs > 0 ? (_endMs / _totalMs).clamp(0.0, 1.0) : 1.0;
                final headRatio = _totalMs > 0
                    ? (_playheadMs / _totalMs).clamp(0.0, 1.0)
                    : 0.0;

                final leftPx = startRatio * trackW;
                final rightPx = endRatio * trackW;
                final headPx = headRatio * trackW;

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (details) {
                    _dragInitStartMs = _startMs;
                    _dragInitEndMs = _endMs;
                    _dragInitDx = details.localPosition.dx;
                    final x = details.localPosition.dx;
                    if ((x - leftPx).abs() <= 24) {
                      _dragMode = _TrimDragMode.start;
                    } else if ((x - rightPx).abs() <= 24) {
                      _dragMode = _TrimDragMode.end;
                    } else if (x > leftPx && x < rightPx) {
                      _dragMode = _TrimDragMode.window;
                    } else {
                      _dragMode = _TrimDragMode.none;
                    }
                  },
                  onHorizontalDragUpdate: (details) {
                    if (_dragMode == _TrimDragMode.none || trackW <= 0) return;
                    final deltaRatio =
                        (details.localPosition.dx - _dragInitDx) / trackW;
                    final deltaMs = (deltaRatio * _totalMs).round();

                    setState(() {
                      if (_dragMode == _TrimDragMode.window) {
                        final span = _dragInitEndMs - _dragInitStartMs;
                        final ns = (_dragInitStartMs + deltaMs)
                            .clamp(0, math.max(0, _totalMs - span))
                            .toInt();
                        _startMs = ns;
                        _endMs = ns + span;
                        _playheadMs = ns;
                        _seekLive(ns);
                      } else if (_dragMode == _TrimDragMode.start) {
                        final ns = (_dragInitStartMs + deltaMs)
                            .clamp(0, math.max(0, _dragInitEndMs - _minClipMs))
                            .toInt();
                        var ne = _dragInitEndMs;
                        if (ne - ns > _maxClipMs) {
                          ne = math.min(_totalMs, ns + _maxClipMs);
                        }
                        _startMs = ns;
                        _endMs = ne;
                        _playheadMs = ns;
                        _seekLive(ns);
                      } else if (_dragMode == _TrimDragMode.end) {
                        final ne = (_dragInitEndMs + deltaMs)
                            .clamp(_dragInitStartMs + _minClipMs, _totalMs)
                            .toInt();
                        var ns = _dragInitStartMs;
                        if (ne - ns > _maxClipMs) {
                          ns = math.max(0, ne - _maxClipMs);
                        }
                        _startMs = ns;
                        _endMs = ne;
                        _playheadMs = ne;
                        _seekLive(ne);
                      }
                    });
                  },
                  onHorizontalDragEnd: (_) {
                    _dragMode = _TrimDragMode.none;
                  },
                  child: SizedBox(
                    height: 62,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          if (_thumbs.isNotEmpty)
                            Row(
                              children: _thumbs.map((p) {
                                return Expanded(
                                  child: Image.file(
                                    File(p),
                                    height: 62,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const ColoredBox(
                                            color: Color(0xFF2D231E)),
                                  ),
                                );
                              }).toList(),
                            )
                          else
                            const ColoredBox(color: Color(0xFF2D231E)),

                          // Zonas descartadas a izquierda y derecha
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            width: leftPx.clamp(0.0, trackW),
                            child: ColoredBox(
                              color: Colors.black.withValues(alpha: 0.66),
                            ),
                          ),
                          Positioned(
                            left: rightPx.clamp(0.0, trackW),
                            right: 0,
                            top: 0,
                            bottom: 0,
                            child: ColoredBox(
                              color: Colors.black.withValues(alpha: 0.66),
                            ),
                          ),

                          // Aguja de reproducción en vivo
                          Positioned(
                            left: (headPx - 1.5).clamp(0.0, trackW - 3),
                            top: 4,
                            bottom: 4,
                            width: 3,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.94),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),

                          // Marco activo con manijas izquierda/derecha
                          Positioned(
                            left: leftPx.clamp(0.0, trackW),
                            width: math.max(24.0, rightPx - leftPx),
                            top: 0,
                            bottom: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: theme.terracotta,
                                  width: 2.6,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  Container(
                                    width: 14,
                                    height: double.infinity,
                                    decoration: BoxDecoration(
                                      color: theme.terracotta,
                                      borderRadius:
                                          const BorderRadius.horizontal(
                                        left: Radius.circular(6),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.drag_indicator_rounded,
                                      size: 11,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Container(
                                    width: 14,
                                    height: double.infinity,
                                    decoration: BoxDecoration(
                                      color: theme.terracotta,
                                      borderRadius:
                                          const BorderRadius.horizontal(
                                        right: Radius.circular(6),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.drag_indicator_rounded,
                                      size: 11,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
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
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
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
                      onPressed: _saving ? null : _confirmTrim,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.content_cut_rounded, size: 18),
                      label: Text(
                        _saving
                            ? 'Recortando video…'
                            : 'Usar este clip ($selectedSecsLabel)',
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

class _TimeAdjustBox extends StatelessWidget {
  const _TimeAdjustBox({
    required this.label,
    required this.timeText,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final String timeText;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        children: <Widget>[
          Text(
            '$label · $timeText',
            style: const TextStyle(
              color: Color(0xFFFAF7F2),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              InkWell(
                onTap: onMinus,
                borderRadius: BorderRadius.circular(999),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Text(
                    '-0.5s',
                    style: TextStyle(
                      color: Color(0xFFE7C7B4),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const Text(
                '·',
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
              InkWell(
                onTap: onPlus,
                borderRadius: BorderRadius.circular(999),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Text(
                    '+0.5s',
                    style: TextStyle(
                      color: Color(0xFFE7C7B4),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
