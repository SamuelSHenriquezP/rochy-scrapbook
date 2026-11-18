import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/bento_node.dart';
import '../../providers/bento_canvas_provider.dart';
import '../../theme/rochy_theme.dart';
import 'bento_card_shell.dart';

/// Tarjeta tipográfica para frases textuales con comillas flotantes translúcidas
/// y selector de reacción afectiva con animación elástica de corazón.
class QuoteCardWidget extends ConsumerStatefulWidget {
  const QuoteCardWidget({
    super.key,
    required this.node,
    required this.payload,
    required this.theme,
    required this.relationHighlight,
    this.showPaperGrain = true,
  });

  final BentoNode node;
  final QuotePayload payload;
  final RochyThemeData theme;
  final BentoRelationHighlight relationHighlight;
  final bool showPaperGrain;

  @override
  ConsumerState<QuoteCardWidget> createState() => _QuoteCardWidgetState();
}

class _QuoteCardWidgetState extends ConsumerState<QuoteCardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _heartController;
  late final Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _heartScale = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.0, end: 1.38)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 45,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.38, end: 0.92)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 28,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.92, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 27,
      ),
    ]).animate(_heartController);
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  void _onHeartTap() {
    HapticFeedback.lightImpact();
    _heartController.forward(from: 0.0);
    ref.read(bentoCanvasProvider.notifier).toggleQuoteLove(widget.node.id);
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.theme.resolveNodeBackground(widget.node);
    final primaryInk = widget.theme.resolveNodePrimaryInk(widget.node);
    final secondaryInk = widget.theme.resolveNodeSecondaryInk(widget.node);

    return BentoCardShell(
      theme: widget.theme,
      node: widget.node,
      backgroundColor: bgColor,
      relationHighlight: widget.relationHighlight,
      showPaperGrain: widget.showPaperGrain,
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 11),
      onTap: _onHeartTap,
      onLongPress: () => ref
          .read(bentoCanvasProvider.notifier)
          .toggleNodeFocus(widget.node.id),
      child: Stack(
        children: <Widget>[
          // Comillas decorativas flotantes semi-translúcidas
          Positioned(
            top: -12,
            left: -2,
            child: IgnorePointer(
              child: Text(
                '“',
                style: RochyTypography.cardSerifTitle(
                  primaryInk.withValues(alpha: 0.14),
                  fontSize: 72,
                  height: 1.0,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            right: 2,
            child: IgnorePointer(
              child: Text(
                '”',
                style: RochyTypography.cardSerifTitle(
                  primaryInk.withValues(alpha: 0.12),
                  fontSize: 58,
                  height: 1.0,
                ),
              ),
            ),
          ),

          LayoutBuilder(
            builder: (context, constraints) {
              final isStrip = constraints.maxHeight < 110;
              if (isStrip) {
                return Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '“${widget.payload.quoteText}”',
                        textAlign: RochyTypography.toFlutterTextAlign(
                          widget.node.textAlign,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: RochyTypography.resolveCardTitle(
                          widget.node.fontStyle,
                          primaryInk,
                          fontSize: 14.5 * widget.node.titleScale,
                          fontWeight: widget.node.isTitleBold
                              ? FontWeight.w600
                              : FontWeight.w400,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ScaleTransition(
                      scale: _heartScale,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: primaryInk.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              widget.payload.isLoved
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 13,
                              color: widget.payload.isLoved
                                  ? const Color(0xFFFFD8C8)
                                  : primaryInk.withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.payload.loveCount}',
                              style: RochyTypography.metadata(
                                primaryInk,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }

              return Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const SizedBox(height: 4),
                  Expanded(
                    child: Center(
                      child: Text(
                        '“${widget.payload.quoteText}”',
                        textAlign: RochyTypography.toFlutterTextAlign(
                          widget.node.textAlign,
                        ),
                        maxLines: constraints.maxHeight > 200 ? 6 : 4,
                        overflow: TextOverflow.ellipsis,
                        style: RochyTypography.resolveCardTitle(
                          widget.node.fontStyle,
                          primaryInk,
                          fontSize: (constraints.maxHeight > 200 ? 20.0 : 18.0) *
                              widget.node.titleScale,
                          fontWeight: widget.node.isTitleBold
                              ? FontWeight.w600
                              : FontWeight.w400,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          widget.payload.contextLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: RochyTypography.metadata(
                            secondaryInk.withValues(alpha: 0.85),
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                      ScaleTransition(
                        scale: _heartScale,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: primaryInk.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                widget.payload.isLoved
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                size: 14,
                                color: widget.payload.isLoved
                                    ? const Color(0xFFFFD8C8)
                                    : primaryInk.withValues(alpha: 0.8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.payload.loveCount}',
                                style: RochyTypography.metadata(
                                  primaryInk,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
