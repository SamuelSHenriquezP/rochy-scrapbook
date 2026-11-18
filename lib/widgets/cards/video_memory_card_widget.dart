import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../models/bento_node.dart';
import '../../providers/bento_canvas_provider.dart';
import '../../theme/rochy_theme.dart';
import '../editorial_image.dart';
import 'bento_card_shell.dart';

/// Tarjeta de recuerdo en video con estética Super-8 editorial, reproducción
/// real mediante [VideoPlayerController] (archivo local o URL) y visor modal.
class VideoMemoryCardWidget extends ConsumerStatefulWidget {
  const VideoMemoryCardWidget({
    super.key,
    required this.node,
    required this.payload,
    required this.theme,
    required this.relationHighlight,
    this.showPaperGrain = true,
  });

  final BentoNode node;
  final VideoMemoryPayload payload;
  final RochyThemeData theme;
  final BentoRelationHighlight relationHighlight;
  final bool showPaperGrain;

  @override
  ConsumerState<VideoMemoryCardWidget> createState() =>
      _VideoMemoryCardWidgetState();
}

class _VideoMemoryCardWidgetState extends ConsumerState<VideoMemoryCardWidget> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    _muted = widget.payload.autoPlayMuted;
    _initController();
  }

  @override
  void didUpdateWidget(covariant VideoMemoryCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.payload.videoSource != widget.payload.videoSource) {
      _disposeController();
      _initController();
    }
  }

  Future<void> _initController() async {
    final source = widget.payload.videoSource.trim();
    if (source.isEmpty) return;

    try {
      final isRemote =
          source.startsWith('http://') || source.startsWith('https://');
      final VideoPlayerController ctrl;
      if (isRemote) {
        ctrl = VideoPlayerController.networkUrl(Uri.parse(source));
      } else if (!kIsWeb && File(source).existsSync()) {
        ctrl = VideoPlayerController.file(File(source));
      } else {
        return;
      }

      _controller = ctrl;
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.setVolume(_muted ? 0.0 : 1.0);
      if (widget.payload.autoPlayMuted) {
        await ctrl.play();
      }
      if (mounted) {
        setState(() => _initialized = true);
        // Si el video es vertical y aún ocupa 2 columnas horizontales, ajústalo orgánicamente a 1×3.
        if (ctrl.value.aspectRatio > 0 &&
            ctrl.value.aspectRatio < 0.85 &&
            widget.node.colSpan == 2 &&
            widget.node.rowSpan == 2) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ref
                .read(bentoCanvasProvider.notifier)
                .resizeNode(widget.node.id, colSpan: 1, rowSpan: 3);
          });
        }
      }
    } catch (_) {
      _disposeController();
    }
  }

  void _disposeController() {
    final old = _controller;
    _controller = null;
    _initialized = false;
    old?.dispose();
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _toggleMute() {
    HapticFeedback.selectionClick();
    final nextMuted = !_muted;
    setState(() => _muted = nextMuted);
    _controller?.setVolume(nextMuted ? 0.0 : 1.0);
    if (_controller != null && !(_controller!.value.isPlaying)) {
      _controller!.play();
    }
  }

  void _openVideoModal() {
    HapticFeedback.lightImpact();
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.86),
      builder: (dialogContext) => _VideoStoryModal(
        payload: widget.payload,
        theme: widget.theme,
        sharedController: _controller,
        isInitialized: _initialized,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;

    return BentoCardShell(
      theme: widget.theme,
      node: widget.node,
      backgroundColor: widget.theme.resolveNodeBackground(widget.node),
      relationHighlight: widget.relationHighlight,
      showPaperGrain: widget.showPaperGrain,
      borderRadius: widget.node.borderRadius,
      onTap: _openVideoModal,
      onLongPress: () => ref
          .read(bentoCanvasProvider.notifier)
          .toggleNodeFocus(widget.node.id),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (_initialized && ctrl != null)
            FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: ctrl.value.size.width,
                height: ctrl.value.size.height,
                child: VideoPlayer(ctrl),
              ),
            )
          else
            EditorialImage(
              imageUrl: widget.payload.thumbnailUrl,
              fallbackScene: EditorialFallbackScene.cinemaReel,
            ),

          // Gradiente inferior orgánico (solo si hay texto que resaltar)
          if (widget.payload.title.isNotEmpty ||
              widget.payload.locationLabel.isNotEmpty ||
              widget.payload.dateLabel.isNotEmpty)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const <double>[0.25, 0.70, 1.0],
                  colors: <Color>[
                    Colors.black.withValues(alpha: 0.14),
                    const Color(0xFF231712).withValues(alpha: 0.36),
                    const Color(0xFF1A110C).withValues(alpha: 0.82),
                  ],
                ),
              ),
            ),

          // Etiqueta superior tipo carrete Super-8 + botón de sonido
          Positioned(
            top: 11,
            left: 11,
            right: 11,
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.36),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.videocam_rounded,
                        size: 12,
                        color: Color(0xFFFAF7F2),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _initialized ? 'En vivo' : 'Video',
                        style: RochyTypography.metadata(
                          const Color(0xFFFAF7F2),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _toggleMute,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.38),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Icon(
                      _muted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      size: 14,
                      color: const Color(0xFFFAF7F2),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Botón central sutil de play si aún no reproduce automáticamente
          if (!_initialized || !(ctrl?.value.isPlaying ?? false))
            Center(
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F2).withValues(alpha: 0.24),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  size: 24,
                  color: Color(0xFFFAF7F2),
                ),
              ),
            ),

          // Pie editorial con título, lugar y fecha (solo si el usuario escribió alguno)
          if (widget.payload.title.isNotEmpty ||
              widget.payload.locationLabel.isNotEmpty ||
              widget.payload.dateLabel.isNotEmpty)
            Positioned(
              left: 13,
              right: 13,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (widget.payload.locationLabel.isNotEmpty ||
                      widget.payload.dateLabel.isNotEmpty)
                    Text(
                      [
                        if (widget.payload.locationLabel.isNotEmpty)
                          widget.payload.locationLabel,
                        if (widget.payload.dateLabel.isNotEmpty)
                          widget.payload.dateLabel,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RochyTypography.metadata(
                        const Color(0xFFFAF7F2).withValues(alpha: 0.84),
                        fontSize: 10.5,
                      ),
                    ),
                  if (widget.payload.title.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      widget.payload.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: RochyTypography.resolveCardTitle(
                        widget.node.fontStyle,
                        const Color(0xFFFAF7F2),
                        fontSize: 16.5 * widget.node.titleScale,
                        fontWeight: widget.node.isTitleBold
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _VideoStoryModal extends StatefulWidget {
  const _VideoStoryModal({
    required this.payload,
    required this.theme,
    required this.sharedController,
    required this.isInitialized,
  });

  final VideoMemoryPayload payload;
  final RochyThemeData theme;
  final VideoPlayerController? sharedController;
  final bool isInitialized;

  @override
  State<_VideoStoryModal> createState() => _VideoStoryModalState();
}

class _VideoStoryModalState extends State<_VideoStoryModal> {
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    final ctrl = widget.sharedController;
    if (ctrl != null && widget.isInitialized) {
      ctrl.setVolume(1.0);
      ctrl.play();
    }
  }

  @override
  void dispose() {
    final ctrl = widget.sharedController;
    if (ctrl != null && widget.isInitialized && widget.payload.autoPlayMuted) {
      ctrl.setVolume(0.0);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.sharedController;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1F1713),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.16),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AspectRatio(
              aspectRatio: widget.isInitialized && ctrl != null
                  ? ctrl.value.aspectRatio.clamp(0.65, 1.8)
                  : 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  if (widget.isInitialized && ctrl != null)
                    VideoPlayer(ctrl)
                  else
                    EditorialImage(
                      imageUrl: widget.payload.thumbnailUrl,
                      fallbackScene: EditorialFallbackScene.cinemaReel,
                    ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.48),
                        foregroundColor: const Color(0xFFFAF7F2),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.isInitialized && ctrl != null)
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: ctrl,
                builder: (context, value, _) {
                  final total = value.duration.inMilliseconds;
                  final pos = value.position.inMilliseconds;
                  final progress = total > 0 ? (pos / total).clamp(0.0, 1.0) : 0.0;

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                    child: Row(
                      children: <Widget>[
                        IconButton(
                          onPressed: () {
                            if (value.isPlaying) {
                              ctrl.pause();
                            } else {
                              ctrl.play();
                            }
                          },
                          icon: Icon(
                            value.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: const Color(0xFFFAF7F2),
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: progress,
                            activeColor: widget.theme.terracotta,
                            inactiveColor: Colors.white.withValues(alpha: 0.2),
                            onChanged: (v) {
                              ctrl.seekTo(
                                Duration(milliseconds: (v * total).round()),
                              );
                            },
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() => _muted = !_muted);
                            ctrl.setVolume(_muted ? 0.0 : 1.0);
                          },
                          icon: Icon(
                            _muted
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                            color: const Color(0xFFFAF7F2),
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.payload.title,
                    style: RochyTypography.cardSerifTitle(
                      const Color(0xFFFAF7F2),
                      fontSize: 20,
                    ),
                  ),
                  if (widget.payload.caption.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      widget.payload.caption,
                      style: RochyTypography.sansBody(
                        const Color(0xFFFAF7F2).withValues(alpha: 0.8),
                        fontSize: 13.5,
                      ),
                    ),
                  ] else if (!widget.isInitialized) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      'Adjunta un video desde tu galería o pega un enlace en el editor para reproducirlo aquí.',
                      style: RochyTypography.sansBody(
                        const Color(0xFFFAF7F2).withValues(alpha: 0.7),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
