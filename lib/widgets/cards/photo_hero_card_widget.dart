import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/bento_node.dart';
import '../../providers/bento_canvas_provider.dart';
import '../../theme/rochy_theme.dart';
import '../../views/story_detail_view.dart';
import '../editorial_image.dart';
import 'bento_card_shell.dart';

/// Tarjeta fotográfica inmersiva con parallax sutil, gradiente orgánico inferior
/// y transición expansiva tipo Hero hacia el visor detallado de la historia.
class PhotoHeroCardWidget extends ConsumerStatefulWidget {
  const PhotoHeroCardWidget({
    super.key,
    required this.node,
    required this.payload,
    required this.theme,
    required this.relationHighlight,
    this.showPaperGrain = true,
  });

  final BentoNode node;
  final PhotoHeroPayload payload;
  final RochyThemeData theme;
  final BentoRelationHighlight relationHighlight;
  final bool showPaperGrain;

  @override
  ConsumerState<PhotoHeroCardWidget> createState() =>
      _PhotoHeroCardWidgetState();
}

class _PhotoHeroCardWidgetState extends ConsumerState<PhotoHeroCardWidget> {
  ScrollPosition? _scrollPosition;
  double _parallaxOffset = 0.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextPosition = Scrollable.maybeOf(context)?.position;
    if (_scrollPosition != nextPosition) {
      _scrollPosition?.removeListener(_updateParallax);
      _scrollPosition = nextPosition;
      _scrollPosition?.addListener(_updateParallax);
      _updateParallax();
    }
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_updateParallax);
    super.dispose();
  }

  void _updateParallax() {
    final pos = _scrollPosition;
    if (pos == null || !pos.hasPixels || !mounted) return;
    final nextOffset = (pos.pixels * 0.08).clamp(-14.0, 14.0);
    if ((nextOffset - _parallaxOffset).abs() > 0.3) {
      setState(() => _parallaxOffset = nextOffset);
    }
  }

  void _openStoryDetail() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 520),
        reverseTransitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: StoryDetailView(nodeId: widget.node.id),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BentoCardShell(
      theme: widget.theme,
      node: widget.node,
      backgroundColor: widget.theme.resolveNodeBackground(widget.node),
      relationHighlight: widget.relationHighlight,
      showPaperGrain: widget.showPaperGrain,
      borderRadius: widget.node.borderRadius,
      onTap: _openStoryDetail,
      onLongPress: () => ref
          .read(bentoCanvasProvider.notifier)
          .toggleNodeFocus(widget.node.id),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Fotografía con Hero compartido y ligero desplazamiento parallax
          Hero(
            tag: 'hero_photo_${widget.node.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.node.borderRadius),
              child: Transform.translate(
                offset: Offset(0, -_parallaxOffset),
                child: Transform.scale(
                  scale: 1.08,
                  child: EditorialImage(
                    imageUrl: widget.payload.imageUrl,
                    fallbackScene: EditorialFallbackScene.cafeSunlit,
                    alignment: const Alignment(0, -0.25),
                  ),
                ),
              ),
            ),
          ),

          // Gradiente orgánico inferior (solo si hay texto que resaltar)
          if (widget.payload.title.isNotEmpty ||
              widget.payload.locationLabel.isNotEmpty ||
              widget.payload.dateLabel.isNotEmpty)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const <double>[0.35, 0.72, 1.0],
                  colors: <Color>[
                    Colors.transparent,
                    const Color(0xFF231712).withValues(alpha: 0.30),
                    const Color(0xFF1D130E).withValues(alpha: 0.78),
                  ],
                ),
              ),
            ),

          // Metadatos y título Serif incrustado (se adapta a tarjetas estrechas o verticales)
          if (widget.payload.title.isNotEmpty ||
              widget.payload.locationLabel.isNotEmpty ||
              widget.payload.dateLabel.isNotEmpty)
            Positioned(
              left: 14,
              right: 14,
              bottom: 13,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 185;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (widget.payload.locationLabel.isNotEmpty ||
                          widget.payload.dateLabel.isNotEmpty)
                        Row(
                          children: <Widget>[
                            if (widget.payload.locationLabel.isNotEmpty)
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFAF7F2)
                                        .withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.30),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      const Icon(
                                        Icons.location_on_rounded,
                                        size: 11,
                                        color: Color(0xFFFAF7F2),
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          widget.payload.locationLabel,
                                          maxLines: 2,
                                          softWrap: true,
                                          overflow: TextOverflow.ellipsis,
                                          style: RochyTypography.metadata(
                                            const Color(0xFFFAF7F2),
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (!isNarrow &&
                                widget.payload.dateLabel.isNotEmpty) ...<Widget>[
                              if (widget.payload.locationLabel.isNotEmpty)
                                const Spacer(),
                              Text(
                                widget.payload.dateLabel,
                                style: RochyTypography.metadata(
                                  const Color(0xFFFAF7F2)
                                      .withValues(alpha: 0.9),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      if (isNarrow && widget.payload.dateLabel.isNotEmpty) ...<Widget>[
                        if (widget.payload.locationLabel.isNotEmpty)
                          const SizedBox(height: 4),
                        Text(
                          widget.payload.dateLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: RochyTypography.metadata(
                            const Color(0xFFFAF7F2).withValues(alpha: 0.88),
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                      if (widget.payload.title.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(
                          widget.payload.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: RochyTypography.toFlutterTextAlign(
                            widget.node.textAlign,
                          ),
                          style: RochyTypography.resolveCardTitle(
                            widget.node.fontStyle,
                            const Color(0xFFFAF7F2),
                            fontSize:
                                (isNarrow ? 16 : 18.5) * widget.node.titleScale,
                            fontWeight: widget.node.isTitleBold
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
