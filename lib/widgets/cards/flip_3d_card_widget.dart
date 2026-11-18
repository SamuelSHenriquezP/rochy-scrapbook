import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/bento_node.dart';
import '../../providers/bento_canvas_provider.dart';
import '../../theme/rochy_theme.dart';
import '../waveform_painter.dart';
import 'bento_card_shell.dart';

/// Tarjeta interactiva de doble cara con proyección 3D real en el eje Y.
///
/// - Cara A: Ícono cálido de café con arte latte, título Serif y micro-texto.
/// - Cara B: Reproductor de nota de voz con forma de onda interactiva, fecha
///   de grabación y botón Play/Pause con retroalimentación háptica.
class Flip3DCardWidget extends ConsumerStatefulWidget {
  const Flip3DCardWidget({
    super.key,
    required this.node,
    required this.payload,
    required this.theme,
    required this.relationHighlight,
    this.showPaperGrain = true,
  });

  final BentoNode node;
  final FlipDetailPayload payload;
  final RochyThemeData theme;
  final BentoRelationHighlight relationHighlight;
  final bool showPaperGrain;

  @override
  ConsumerState<Flip3DCardWidget> createState() => _Flip3DCardWidgetState();
}

class _Flip3DCardWidgetState extends ConsumerState<Flip3DCardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _flipAnimation = CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    HapticFeedback.lightImpact();
    final nextIsFront = !_isFront;
    setState(() => _isFront = nextIsFront);
    if (nextIsFront) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    ref
        .read(bentoCanvasProvider.notifier)
        .setCardFlipped(widget.node.id, !nextIsFront);
  }

  @override
  Widget build(BuildContext context) {
    final activeAudioId =
        ref.watch(bentoCanvasProvider.select((s) => s.activeAudioNodeId));
    final isAudioPlaying =
        ref.watch(bentoCanvasProvider.select((s) => s.isAudioPlaying));
    final audioProgress =
        ref.watch(bentoCanvasProvider.select((s) => s.audioProgress));

    final isThisPlaying =
        activeAudioId == widget.node.id && isAudioPlaying;
    final currentProgress =
        activeAudioId == widget.node.id ? audioProgress : 0.0;

    return AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, _) {
        final animValue = _flipAnimation.value;
        final angle = animValue * math.pi;
        final showFront = animValue <= 0.5;

        // Sombreado especular dinámico cuando el plano gira de canto hacia la cámara.
        final edgeShade = (math.sin(angle).abs() * 0.16).clamp(0.0, 0.16);

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
            ..rotateY(angle),
          child: showFront
              ? _buildCardFace(
                  isBack: false,
                  edgeShade: edgeShade,
                  child: _FrontDetailFace(
                    node: widget.node,
                    payload: widget.payload,
                    theme: widget.theme,
                  ),
                )
              : Transform(
                  alignment: Alignment.center,
                  // Contrarrotación de PI para evitar texto invertido en espejo.
                  transform: Matrix4.rotationY(math.pi),
                  child: _buildCardFace(
                    isBack: true,
                    edgeShade: edgeShade,
                    child: _BackVoiceFace(
                      nodeId: widget.node.id,
                      payload: widget.payload,
                      theme: widget.theme,
                      colorTheme: widget.node.colorTheme,
                      isPlaying: isThisPlaying,
                      progress: currentProgress,
                      onFlipBack: _toggleFlip,
                      onTogglePlay: () {
                        HapticFeedback.lightImpact();
                        ref
                            .read(bentoCanvasProvider.notifier)
                            .toggleAudioPlayback(
                              widget.node.id,
                              durationSeconds: widget.payload.durationSeconds,
                            );
                      },
                      onSeek: (ratio) {
                        ref.read(bentoCanvasProvider.notifier).seekAudio(
                              widget.node.id,
                              ratio,
                              durationSeconds: widget.payload.durationSeconds,
                            );
                      },
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildCardFace({
    required bool isBack,
    required double edgeShade,
    required Widget child,
  }) {
    final baseColor = widget.theme.resolveNodeBackground(widget.node);
    final surfaceColor = isBack
        ? Color.lerp(baseColor, const Color(0xFF231610), 0.18)!
        : baseColor;

    return BentoCardShell(
      theme: widget.theme,
      node: widget.node,
      backgroundColor: Color.lerp(surfaceColor, Colors.black, edgeShade)!,
      relationHighlight: widget.relationHighlight,
      showPaperGrain: widget.showPaperGrain,
      padding: const EdgeInsets.all(13),
      onTap: _toggleFlip,
      onLongPress: () => ref
          .read(bentoCanvasProvider.notifier)
          .toggleNodeFocus(widget.node.id),
      child: child,
    );
  }
}

class _FrontDetailFace extends StatelessWidget {
  const _FrontDetailFace({
    required this.node,
    required this.payload,
    required this.theme,
  });

  final BentoNode node;
  final FlipDetailPayload payload;
  final RochyThemeData theme;

  @override
  Widget build(BuildContext context) {
    final primaryInk = theme.resolveNodePrimaryInk(node);
    final secondaryInk = theme.resolveNodeSecondaryInk(node);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isStrip = constraints.maxHeight < 180;
        final isTallVertical = constraints.maxHeight > 205;

        if (isStrip) {
          return Row(
            children: <Widget>[
              _LatteArtBadge(inkColor: primaryInk, iconKey: payload.iconKey),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      payload.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RochyTypography.resolveCardTitle(
                        node.fontStyle,
                        primaryInk,
                        fontSize: 15 * node.titleScale,
                        fontWeight: node.isTitleBold
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    Text(
                      payload.microText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RochyTypography.sansBody(
                        secondaryInk,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.flip_rounded,
                size: 14,
                color: primaryInk.withValues(alpha: 0.55),
              ),
            ],
          );
        }

        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Align(
              alignment: Alignment.topRight,
              child: Icon(
                Icons.flip_rounded,
                size: 13,
                color: primaryInk.withValues(alpha: 0.45),
              ),
            ),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Transform.scale(
                    scale: isTallVertical ? 1.18 : 1.0,
                    child: _LatteArtBadge(
                      inkColor: primaryInk,
                      iconKey: payload.iconKey,
                    ),
                  ),
                  SizedBox(height: isTallVertical ? 14 : 8),
                  Text(
                    payload.title,
                    textAlign:
                        RochyTypography.toFlutterTextAlign(node.textAlign),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: RochyTypography.resolveCardTitle(
                      node.fontStyle,
                      primaryInk,
                      fontSize: (isTallVertical ? 18 : 16) * node.titleScale,
                      fontWeight: node.isTitleBold
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    payload.microText,
                    textAlign:
                        RochyTypography.toFlutterTextAlign(node.textAlign),
                    maxLines: isTallVertical ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: RochyTypography.sansBody(
                      secondaryInk,
                      fontSize: 11.8,
                      height: 1.24,
                    ),
                  ),
                ],
              ),
            ),
            if (isTallVertical)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryInk.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Toca para girar',
                  style: RochyTypography.metadata(
                    primaryInk.withValues(alpha: 0.8),
                    fontSize: 10,
                  ),
                ),
              )
            else
              const SizedBox(height: 2),
          ],
        );
      },
    );
  }
}

/// Ícono cálido personalizable para rituales 3D (café, flor, sol, música, etc.).
class _LatteArtBadge extends StatelessWidget {
  const _LatteArtBadge({
    required this.inkColor,
    required this.iconKey,
  });

  final Color inkColor;
  final String iconKey;

  IconData _resolveIcon() => switch (iconKey) {
        'flower' => Icons.local_florist_rounded,
        'sun' => Icons.wb_sunny_rounded,
        'music' => Icons.music_note_rounded,
        'book' => Icons.menu_book_rounded,
        'cake' => Icons.cake_rounded,
        'camera' => Icons.photo_camera_rounded,
        'heart' => Icons.favorite_rounded,
        _ => Icons.coffee_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: inkColor.withValues(alpha: 0.12),
        border: Border.all(
          color: inkColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Icon(
            _resolveIcon(),
            color: inkColor.withValues(alpha: 0.92),
            size: 22,
          ),
          if (iconKey == 'coffee')
            Positioned(
              top: 9,
              child: Icon(
                Icons.favorite_rounded,
                size: 7.5,
                color: const Color(0xFFD98B66).withValues(alpha: 0.95),
              ),
            ),
        ],
      ),
    );
  }
}

class _BackVoiceFace extends StatelessWidget {
  const _BackVoiceFace({
    required this.nodeId,
    required this.payload,
    required this.theme,
    required this.colorTheme,
    required this.isPlaying,
    required this.progress,
    required this.onFlipBack,
    required this.onTogglePlay,
    required this.onSeek,
  });

  final String nodeId;
  final FlipDetailPayload payload;
  final RochyThemeData theme;
  final BentoColorTheme colorTheme;
  final bool isPlaying;
  final double progress;
  final VoidCallback onFlipBack;
  final VoidCallback onTogglePlay;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    final primaryInk = theme.cardPrimaryText(colorTheme);
    final secondaryInk = theme.cardSecondaryText(colorTheme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                payload.recordedDateLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RochyTypography.metadata(
                  secondaryInk,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            GestureDetector(
              onTap: onFlipBack,
              child: Icon(
                Icons.rotate_left_rounded,
                size: 16,
                color: primaryInk.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          payload.backSubtitle.isNotEmpty
              ? payload.backSubtitle
              : payload.voiceNoteLabel,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: RochyTypography.cardSerifTitle(
            primaryInk,
            fontSize: 13.5,
            fontStyle: FontStyle.italic,
          ),
        ),
        const Spacer(),
        // Reproductor de nota de voz con forma de onda interactiva
        Row(
          children: <Widget>[
            GestureDetector(
              onTap: onTogglePlay,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPlaying
                      ? const Color(0xFFD98B66)
                      : primaryInk.withValues(alpha: 0.18),
                  border: Border.all(
                    color: primaryInk.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 19,
                  color: primaryInk,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: InteractiveWaveformBar(
                samples: payload.waveformSamples,
                progress: progress,
                isPlaying: isPlaying,
                height: 32,
                activeColor: const Color(0xFFE7A984),
                inactiveColor: primaryInk.withValues(alpha: 0.32),
                onSeek: onSeek,
              ),
            ),
          ],
        ),
        const Spacer(),
        Text(
          isPlaying ? 'Reproduciendo recuerdo…' : 'Toca la tarjeta para girar',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: RochyTypography.metadata(
            secondaryInk.withValues(alpha: 0.75),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
