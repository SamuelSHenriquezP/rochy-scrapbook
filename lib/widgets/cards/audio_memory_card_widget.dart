import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/bento_node.dart';
import '../../providers/bento_canvas_provider.dart';
import '../../theme/rochy_theme.dart';
import '../editorial_image.dart';
import '../waveform_painter.dart';
import 'bento_card_shell.dart';

/// Tarjeta de memoria sonora con visualizador de forma de onda [CustomPainter]
/// y botón Play/Pause con morphing animado ([AnimatedIcon]).
class AudioMemoryCardWidget extends ConsumerStatefulWidget {
  const AudioMemoryCardWidget({
    super.key,
    required this.node,
    required this.payload,
    required this.theme,
    required this.relationHighlight,
    this.showPaperGrain = true,
  });

  final BentoNode node;
  final AudioNotePayload payload;
  final RochyThemeData theme;
  final BentoRelationHighlight relationHighlight;
  final bool showPaperGrain;

  @override
  ConsumerState<AudioMemoryCardWidget> createState() =>
      _AudioMemoryCardWidgetState();
}

class _AudioMemoryCardWidgetState extends ConsumerState<AudioMemoryCardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _iconController;

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
  }

  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

  void _syncPlayIcon(bool isPlaying) {
    if (isPlaying && _iconController.status != AnimationStatus.completed) {
      _iconController.forward();
    } else if (!isPlaying &&
        _iconController.status != AnimationStatus.dismissed) {
      _iconController.reverse();
    }
  }

  void _togglePlayback() {
    HapticFeedback.lightImpact();
    ref.read(bentoCanvasProvider.notifier).toggleAudioPlayback(
          widget.node.id,
          durationSeconds: widget.payload.durationSeconds,
        );
  }

  @override
  Widget build(BuildContext context) {
    final activeAudioId =
        ref.watch(bentoCanvasProvider.select((s) => s.activeAudioNodeId));
    final isAudioPlaying =
        ref.watch(bentoCanvasProvider.select((s) => s.isAudioPlaying));
    final audioProgress =
        ref.watch(bentoCanvasProvider.select((s) => s.audioProgress));

    final isPlaying = activeAudioId == widget.node.id && isAudioPlaying;
    final progress = activeAudioId == widget.node.id ? audioProgress : 0.0;
    _syncPlayIcon(isPlaying);

    final bgColor = widget.theme.resolveNodeBackground(widget.node);
    final primaryInk = widget.theme.resolveNodePrimaryInk(widget.node);
    final secondaryInk = widget.theme.resolveNodeSecondaryInk(widget.node);

    return BentoCardShell(
      theme: widget.theme,
      node: widget.node,
      backgroundColor: bgColor,
      relationHighlight: widget.relationHighlight,
      showPaperGrain: widget.showPaperGrain,
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 12),
      onTap: _togglePlayback,
      onLongPress: () => ref
          .read(bentoCanvasProvider.notifier)
          .toggleNodeFocus(widget.node.id),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isStrip = constraints.maxHeight < 118;
          final isTallVertical = constraints.maxHeight > 215;

          if (isStrip) {
            return Row(
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: EditorialImage(
                      imageUrl: widget.payload.coverImageUrl,
                      fallbackScene: EditorialFallbackScene.vinylWarm,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.payload.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RochyTypography.resolveCardTitle(
                          widget.node.fontStyle,
                          primaryInk,
                          fontSize: 14 * widget.node.titleScale,
                          fontWeight: widget.node.isTitleBold
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      Text(
                        widget.payload.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RochyTypography.metadata(
                          secondaryInk,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _togglePlayback,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isPlaying
                          ? widget.theme.terracotta
                          : primaryInk.withValues(alpha: 0.09),
                    ),
                    child: Center(
                      child: AnimatedIcon(
                        icon: AnimatedIcons.play_pause,
                        progress: _iconController,
                        size: 18,
                        color:
                            isPlaying ? const Color(0xFFFAF7F2) : primaryInk,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          if (isTallVertical) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: EditorialImage(
                        imageUrl: widget.payload.coverImageUrl,
                        fallbackScene: EditorialFallbackScene.vinylWarm,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.payload.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: RochyTypography.resolveCardTitle(
                    widget.node.fontStyle,
                    primaryInk,
                    fontSize: 15.5 * widget.node.titleScale,
                    fontWeight: widget.node.isTitleBold
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.payload.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: RochyTypography.metadata(secondaryInk, fontSize: 11),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    GestureDetector(
                      onTap: _togglePlayback,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isPlaying
                              ? widget.theme.terracotta
                              : primaryInk.withValues(alpha: 0.09),
                        ),
                        child: Center(
                          child: AnimatedIcon(
                            icon: AnimatedIcons.play_pause,
                            progress: _iconController,
                            size: 18,
                            color: isPlaying
                                ? const Color(0xFFFAF7F2)
                                : primaryInk,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InteractiveWaveformBar(
                        samples: widget.payload.waveformSamples,
                        progress: progress,
                        isPlaying: isPlaying,
                        height: 28,
                        activeColor: widget.theme.terracotta,
                        inactiveColor: primaryInk.withValues(alpha: 0.28),
                        onSeek: (ratio) {
                          ref.read(bentoCanvasProvider.notifier).seekAudio(
                                widget.node.id,
                                ratio,
                                durationSeconds: widget.payload.durationSeconds,
                              );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              // Fila superior: carátula miniatura + forma de onda + botón Play/Pause
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 38,
                      height: 38,
                      child: EditorialImage(
                        imageUrl: widget.payload.coverImageUrl,
                        fallbackScene: EditorialFallbackScene.vinylWarm,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InteractiveWaveformBar(
                      samples: widget.payload.waveformSamples,
                      progress: progress,
                      isPlaying: isPlaying,
                      height: 30,
                      activeColor: widget.theme.terracotta,
                      inactiveColor: primaryInk.withValues(alpha: 0.28),
                      onSeek: (ratio) {
                        ref.read(bentoCanvasProvider.notifier).seekAudio(
                              widget.node.id,
                              ratio,
                              durationSeconds: widget.payload.durationSeconds,
                            );
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _togglePlayback,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isPlaying
                            ? widget.theme.terracotta
                            : primaryInk.withValues(alpha: 0.09),
                      ),
                      child: Center(
                        child: AnimatedIcon(
                          icon: AnimatedIcons.play_pause,
                          progress: _iconController,
                          size: 17,
                          color: isPlaying
                              ? const Color(0xFFFAF7F2)
                              : primaryInk,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                widget.payload.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign:
                    RochyTypography.toFlutterTextAlign(widget.node.textAlign),
                style: RochyTypography.resolveCardTitle(
                  widget.node.fontStyle,
                  primaryInk,
                  fontSize: 15.0 * widget.node.titleScale,
                  fontWeight: widget.node.isTitleBold
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                widget.payload.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RochyTypography.metadata(
                  secondaryInk,
                  fontSize: 11,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
